import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { verifySlackSignature } from "../src/slack.js";

async function hmacHex(secret, base) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(base));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

describe("verifySlackSignature", () => {
  it("accepts a valid v0 HMAC", async () => {
    const secret = "signing-secret";
    const rawBody = "payload=%7B%22ok%22%3Atrue%7D";
    const timestamp = String(Math.floor(Date.now() / 1000));
    const hex = await hmacHex(secret, `v0:${timestamp}:${rawBody}`);
    const request = new Request("https://example.test/slack/interactions", {
      method: "POST",
      headers: {
        "x-slack-signature": `v0=${hex}`,
        "x-slack-request-timestamp": timestamp,
      },
      body: rawBody,
    });
    assert.equal(await verifySlackSignature(request, secret, rawBody), true);
  });

  it("rejects a wrong HMAC", async () => {
    const request = new Request("https://example.test/slack/interactions", {
      method: "POST",
      headers: {
        "x-slack-signature": "v0=00".repeat(32),
        "x-slack-request-timestamp": String(Math.floor(Date.now() / 1000)),
      },
      body: "payload=",
    });
    assert.equal(await verifySlackSignature(request, "signing-secret", "payload="), false);
  });
});
