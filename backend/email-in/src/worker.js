// Ben email-in: receives Postmark's inbound webhook, matches the address
// token, and stores bill attachments in R2 until the app fetches them.
//
// Flow: user forwards a bill to bills-<token>@in.benandbill.app. Postmark
// receives it (MX on in.benandbill.app) and POSTs the parsed message here.
//
// HUMAN/TODO: /pending and /claim must check real user auth once the account
// backend exists; the token alone is capability-style security (unguessable,
// but treat it like a password: never log it).

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.searchParams.get("secret") !== env.WEBHOOK_SECRET) {
      return new Response("nope", { status: 401 });
    }

    if (request.method === "POST" && url.pathname === "/inbound") {
      return handleInbound(await request.json(), env);
    }
    if (request.method === "GET" && url.pathname.startsWith("/pending/")) {
      return listPending(url.pathname.split("/")[2], env);
    }
    if (request.method === "GET" && url.pathname.startsWith("/blob/")) {
      return fetchBlob(decodeURIComponent(url.pathname.slice(6)), env);
    }
    return new Response("not found", { status: 404 });
  },
};

async function handleInbound(message, env) {
  // "bills-7d1c0c61@in.benandbill.app" -> token "7d1c0c61"
  const to = (message.ToFull?.[0]?.Email ?? message.To ?? "").toLowerCase();
  const token = to.match(/^bills-([a-z0-9]+)@/)?.[1];
  if (!token) return new Response("unroutable", { status: 200 });

  const attachments = (message.Attachments ?? []).filter((a) =>
    /pdf|image/.test(a.ContentType ?? "")
  );
  for (const attachment of attachments) {
    const key = `${token}/${Date.now()}-${attachment.Name ?? "bill"}`;
    await env.INBOUND.put(key, base64ToBytes(attachment.Content), {
      httpMetadata: { contentType: attachment.ContentType },
      customMetadata: { from: message.From ?? "", subject: message.Subject ?? "" },
    });
  }
  return new Response("ok", { status: 200 });
}

async function listPending(token, env) {
  if (!/^[a-z0-9]+$/.test(token ?? "")) return new Response("bad token", { status: 400 });
  const listing = await env.INBOUND.list({ prefix: `${token}/` });
  const items = listing.objects.map((object) => ({
    key: object.key,
    uploaded: object.uploaded,
    size: object.size,
  }));
  return Response.json({ items });
}

async function fetchBlob(key, env) {
  const object = await env.INBOUND.get(key);
  if (!object) return new Response("gone", { status: 404 });
  return new Response(object.body, {
    headers: { "content-type": object.httpMetadata?.contentType ?? "application/octet-stream" },
  });
}

function base64ToBytes(base64) {
  const binary = atob(base64 ?? "");
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
