// Ben email-in: the mailroom for forwarded bills.
//
// Two kinds of caller:
//   1. Postmark (the mail service) POSTs each inbound email to /inbound,
//      authenticated with the shared WEBHOOK_SECRET. We stash any PDF/image
//      attachment in R2 under the recipient's token.
//   2. The app, on behalf of a logged-in user. It sends a Firebase ID token
//      (proof of login) as `Authorization: Bearer <token>`. We verify it,
//      look up which email token belongs to that user, and only ever hand
//      back that user's own bills.
//
// D1 (ACCOUNTS) maps a Firebase user id -> their private email token.
// R2 (INBOUND) stores the actual attachments, keyed `<token>/<ts>-<name>`.

import { verifyFirebaseToken } from "./firebase-auth.js";

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      const route = `${request.method} ${url.pathname}`;

      // Postmark inbound webhook — shared-secret auth, no user context.
      if (request.method === "POST" && url.pathname === "/inbound") {
        if (!secretMatches(url.searchParams.get("secret"), env.WEBHOOK_SECRET)) {
          return json({ error: "unauthorized" }, 401);
        }
        return handleInbound(await request.json(), env, ctx);
      }

      // Everything else is the app acting for a logged-in user.
      if (route === "POST /register") return withUser(request, env, registerAccount);
      if (route === "GET /pending") return withUser(request, env, listPending);
      if (route === "GET /blob") return withUser(request, env, fetchBlob);
      if (route === "POST /claim") return withUser(request, env, claimBlob);

      return json({ error: "not found" }, 404);
    } catch (error) {
      console.log(JSON.stringify({ level: "error", message: String(error?.message ?? error) }));
      return json({ error: "internal error" }, 500);
    }
  },
};

// ---- Postmark inbound ------------------------------------------------------

async function handleInbound(message, env, ctx) {
  // "bills-7d1c0c61@in.benandbill.app" -> token "7d1c0c61"
  const to = (message.ToFull?.[0]?.Email ?? message.To ?? "").toLowerCase();
  const token = to.match(/^bills-([a-z0-9]+)@/)?.[1];
  if (!token) return json({ status: "unroutable" }, 200);

  // Only accept mail for an address we actually issued.
  const owner = await env.ACCOUNTS
    .prepare("SELECT uid FROM accounts WHERE token = ?")
    .bind(token)
    .first();
  if (!owner) {
    console.log(JSON.stringify({ level: "info", message: "dropped mail for unknown token" }));
    return json({ status: "unknown token" }, 200);
  }

  const attachments = (message.Attachments ?? []).filter((attachment) =>
    /pdf|image/.test(attachment.ContentType ?? "")
  );

  for (const attachment of attachments) {
    const key = `${token}/${Date.now()}-${safeName(attachment.Name)}`;
    await env.INBOUND.put(key, base64ToBytes(attachment.Content), {
      httpMetadata: { contentType: attachment.ContentType },
      customMetadata: {
        from: (message.From ?? "").slice(0, 320),
        subject: (message.Subject ?? "").slice(0, 500),
      },
    });
  }

  return json({ status: "ok", stored: attachments.length }, 200);
}

// ---- Authenticated (app) routes -------------------------------------------

// Verifies the Firebase token, resolves the user, and runs `handler(context)`.
async function withUser(request, env, handler) {
  if (!env.FIREBASE_PROJECT_ID) {
    return json({ error: "auth not configured" }, 503);
  }

  const authorization = request.headers.get("authorization") ?? "";
  const bearer = authorization.match(/^Bearer (.+)$/i)?.[1];
  if (!bearer) return json({ error: "missing token" }, 401);

  let claims;
  try {
    claims = await verifyFirebaseToken(bearer, env.FIREBASE_PROJECT_ID);
  } catch {
    return json({ error: "invalid token" }, 401);
  }

  const url = new URL(request.url);
  return handler({ request, env, url, uid: claims.sub, claims });
}

// POST /register — idempotent. Returns the caller's forwarding address,
// minting a token the first time we see this user.
async function registerAccount({ env, uid, claims }) {
  const existing = await env.ACCOUNTS
    .prepare("SELECT token FROM accounts WHERE uid = ?")
    .bind(uid)
    .first();

  let token = existing?.token;
  if (!token) {
    token = randomToken();
    await env.ACCOUNTS
      .prepare(
        "INSERT INTO accounts (uid, token, email, provider, created_at) VALUES (?, ?, ?, ?, ?)"
      )
      .bind(uid, token, claims.email ?? null, providerOf(claims), nowSeconds())
      .run();
  }

  return json({ token, forwardingAddress: addressFor(token) });
}

// GET /pending — the user's waiting bills.
async function listPending({ env, uid }) {
  const token = await tokenForUser(env, uid);
  if (!token) return json({ items: [] });

  const listing = await env.INBOUND.list({ prefix: `${token}/` });
  const items = listing.objects.map((object) => ({
    key: object.key,
    uploaded: object.uploaded,
    size: object.size,
    from: object.customMetadata?.from ?? "",
    subject: object.customMetadata?.subject ?? "",
    contentType: object.httpMetadata?.contentType ?? "application/octet-stream",
  }));
  return json({ items });
}

// GET /blob?key=... — the bytes of one waiting bill (ownership enforced).
async function fetchBlob({ env, url, uid }) {
  const key = url.searchParams.get("key") ?? "";
  const token = await requireOwnedKey(env, uid, key);
  if (!token) return json({ error: "not found" }, 404);

  const object = await env.INBOUND.get(key);
  if (!object) return json({ error: "gone" }, 404);

  return new Response(object.body, {
    headers: {
      "content-type": object.httpMetadata?.contentType ?? "application/octet-stream",
      "cache-control": "private, no-store",
    },
  });
}

// POST /claim { key } — remove a bill once the app has confirmed it.
async function claimBlob({ request, env, uid }) {
  const { key } = await request.json().catch(() => ({}));
  const token = await requireOwnedKey(env, uid, key ?? "");
  if (!token) return json({ error: "not found" }, 404);

  await env.INBOUND.delete(key);
  return json({ status: "claimed" });
}

// ---- Helpers ---------------------------------------------------------------

async function tokenForUser(env, uid) {
  const row = await env.ACCOUNTS
    .prepare("SELECT token FROM accounts WHERE uid = ?")
    .bind(uid)
    .first();
  return row?.token ?? null;
}

// Confirms the key belongs to this user's token before any read/delete.
async function requireOwnedKey(env, uid, key) {
  if (!/^[a-z0-9]+\/.+/.test(key)) return null;
  const token = await tokenForUser(env, uid);
  if (!token) return null;
  return key.startsWith(`${token}/`) ? token : null;
}

function providerOf(claims) {
  const provider = claims.firebase?.sign_in_provider ?? "";
  if (provider.includes("apple")) return "apple";
  if (provider.includes("google")) return "google";
  if (provider === "password") return "password";
  return provider || "unknown";
}

function addressFor(token) {
  return `bills-${token}@in.benandbill.app`;
}

function randomToken() {
  const bytes = new Uint8Array(10);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeName(name) {
  return (name ?? "bill").replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 100);
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function secretMatches(provided, expected) {
  if (!provided || !expected) return false;
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  if (a.byteLength !== b.byteLength) return false;
  return crypto.subtle.timingSafeEqual(a, b);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function base64ToBytes(base64) {
  const binary = atob(base64 ?? "");
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
