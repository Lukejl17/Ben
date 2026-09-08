// Verifies Firebase ID tokens (RS256) with Google's public keys, using only
// Web Crypto (no dependencies). Public keys are cached in memory for the TTL
// Google advertises, so most requests do no extra network work.
//
// A Firebase ID token is the proof-of-login the app sends us. Verifying it
// here means we trust "who you are" without ever handling passwords.

const JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

// Public keys only — safe to cache across requests (not request-scoped state).
let jwkCache = { keys: null, expiresAt: 0 };

async function getSigningKeys() {
  const now = Date.now();
  if (jwkCache.keys && now < jwkCache.expiresAt) return jwkCache.keys;

  const response = await fetch(JWK_URL);
  if (!response.ok) throw new Error("could not fetch Firebase public keys");

  const body = await response.json();
  const keys = new Map();
  for (const key of body.keys ?? []) keys.set(key.kid, key);

  const cacheControl = response.headers.get("cache-control") ?? "";
  const maxAge = Number(cacheControl.match(/max-age=(\d+)/)?.[1] ?? 3600);
  jwkCache = { keys, expiresAt: now + maxAge * 1000 };
  return keys;
}

function base64UrlToBytes(value) {
  let normalised = value.replace(/-/g, "+").replace(/_/g, "/");
  while (normalised.length % 4) normalised += "=";
  const binary = atob(normalised);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlToString(value) {
  return new TextDecoder().decode(base64UrlToBytes(value));
}

// Returns the verified token payload (payload.sub is the stable user id),
// or throws if anything about the token is not trustworthy.
export async function verifyFirebaseToken(token, projectId) {
  if (!token || !projectId) throw new Error("missing token or project id");

  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("malformed token");
  const [headerB64, payloadB64, signatureB64] = parts;

  const header = JSON.parse(base64UrlToString(headerB64));
  if (header.alg !== "RS256") throw new Error("unexpected signing algorithm");
  if (!header.kid) throw new Error("token missing key id");

  const keys = await getSigningKeys();
  const jwk = keys.get(header.kid);
  if (!jwk) throw new Error("unknown signing key");

  const publicKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signatureValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    base64UrlToBytes(signatureB64),
    data
  );
  if (!signatureValid) throw new Error("bad signature");

  const payload = JSON.parse(base64UrlToString(payloadB64));
  const now = Math.floor(Date.now() / 1000);
  const skew = 60; // tolerate a minute of clock drift

  if (payload.aud !== projectId) throw new Error("wrong audience");
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error("wrong issuer");
  }
  if (typeof payload.exp !== "number" || payload.exp < now - skew) {
    throw new Error("token expired");
  }
  if (typeof payload.iat !== "number" || payload.iat > now + skew) {
    throw new Error("token issued in the future");
  }
  if (!payload.sub) throw new Error("token has no subject");

  return payload;
}
