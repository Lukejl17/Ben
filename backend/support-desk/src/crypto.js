// Constant-time string compare. Workers expose crypto.subtle.timingSafeEqual;
// Node's Web Crypto does not, so tests use a byte XOR fallback.

export function timingSafeEqualString(left, right) {
  if (typeof left !== "string" || typeof right !== "string") return false;
  const enc = new TextEncoder();
  return timingSafeEqualBytes(enc.encode(left), enc.encode(right));
}

export function timingSafeEqualBytes(left, right) {
  if (left.byteLength !== right.byteLength) return false;
  if (typeof crypto.subtle?.timingSafeEqual === "function") {
    return crypto.subtle.timingSafeEqual(left, right);
  }
  const a = left instanceof Uint8Array ? left : new Uint8Array(left);
  const b = right instanceof Uint8Array ? right : new Uint8Array(right);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
