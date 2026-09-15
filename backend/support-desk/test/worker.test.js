import assert from "node:assert/strict";
import { afterEach, beforeEach, describe, it } from "node:test";

import worker from "../src/worker.js";

const WEBHOOK_SECRET = "test-webhook-secret-value";
const SLACK_SIGNING_SECRET = "test-slack-signing-secret";

function createTicketStore() {
  const byId = new Map();
  const byPostmark = new Map();

  return {
    byId,
    prepare(sql) {
      return {
        bind(...args) {
          return {
            async first() {
              if (/SELECT id FROM tickets WHERE postmark_message_id/.test(sql)) {
                const row = byPostmark.get(args[0]);
                return row ? { id: row.id } : null;
              }
              if (/SELECT \* FROM tickets WHERE id/.test(sql)) {
                return byId.get(args[0]) ?? null;
              }
              return null;
            },
            async run() {
              if (/INSERT INTO tickets/.test(sql)) {
                const row = {
                  id: args[0],
                  postmark_message_id: args[1],
                  from_email: args[2],
                  from_name: args[3],
                  subject: args[4],
                  body_text: args[5],
                  body_html: args[6],
                  message_id_header: args[7],
                  playbook_id: args[8],
                  draft_subject: args[9],
                  draft_body: args[10],
                  status: args[11],
                  created_at: args[12],
                  updated_at: args[13],
                  slack_channel: null,
                  slack_message_ts: null,
                  engineer_channel: null,
                  engineer_message_ts: null,
                };
                byId.set(row.id, row);
                byPostmark.set(row.postmark_message_id, row);
                return { success: true };
              }
              if (/SET slack_channel/.test(sql)) {
                const row = byId.get(args[3]);
                if (row) {
                  row.slack_channel = args[0];
                  row.slack_message_ts = args[1];
                  row.updated_at = args[2];
                }
                return { success: true };
              }
              if (/SET engineer_channel/.test(sql)) {
                const row = byId.get(args[3]);
                if (row) {
                  row.engineer_channel = args[0];
                  row.engineer_message_ts = args[1];
                  row.updated_at = args[2];
                }
                return { success: true };
              }
              if (/SET status/.test(sql)) {
                const row = byId.get(args[2]);
                if (row) {
                  row.status = args[0];
                  row.updated_at = args[1];
                }
                return { success: true };
              }
              throw new Error(`unmocked SQL: ${sql}`);
            },
          };
        },
      };
    },
  };
}

function makeEnv(store, extras = {}) {
  return {
    TICKETS: store,
    WEBHOOK_SECRET,
    SLACK_BOT_TOKEN: "xoxb-test",
    SLACK_SIGNING_SECRET,
    SLACK_CHANNEL_ID: "C0BV6LP1X8F",
    ENGINEER_CHANNEL_ID: "C0C0CAR1P9S",
    POSTMARK_SERVER_TOKEN: "pm-token",
    SUPPORT_FROM_EMAIL: "support@benandbill.app",
    ...extras,
  };
}

async function jsonOf(response) {
  return { status: response.status, body: await response.json() };
}

function inboundPayload(overrides = {}) {
  return {
    MessageID: "pm-1",
    From: "Sam <sam@example.com>",
    FromFull: { Email: "sam@example.com", Name: "Sam" },
    Subject: "Refund request",
    TextBody: "I would like a refund for my trial subscription.",
    Headers: [{ Name: "Message-ID", Value: "<cust-msg@example.com>" }],
    ...overrides,
  };
}

async function signSlackBody(rawBody, signingSecret = SLACK_SIGNING_SECRET) {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const base = `v0:${timestamp}:${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(base));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return {
    timestamp,
    signature: `v0=${hex}`,
  };
}

const slackPosts = [];
const postmarkSends = [];
let originalFetch;

describe("support desk worker", () => {
  beforeEach(() => {
    slackPosts.length = 0;
    postmarkSends.length = 0;
    originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, opts = {}) => {
      const href = String(url);
      if (href.includes("slack.com/api/chat.postMessage")) {
        const body = JSON.parse(opts.body);
        slackPosts.push(body);
        return new Response(
          JSON.stringify({ ok: true, channel: body.channel, ts: `${slackPosts.length}.000` }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }
      if (href.includes("slack.com/api/chat.update")) {
        slackPosts.push({ type: "update", ...JSON.parse(opts.body) });
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      if (href.includes("api.postmarkapp.com/email")) {
        postmarkSends.push(JSON.parse(opts.body));
        return new Response(JSON.stringify({ ErrorCode: 0, Message: "OK", MessageID: "out-1" }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      throw new Error(`unexpected fetch ${href}`);
    };
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("returns ok on GET /health", async () => {
    const response = await worker.fetch(
      new Request("https://ben-support-desk.test/health"),
      makeEnv(createTicketStore())
    );
    const { status, body } = await jsonOf(response);
    assert.equal(status, 200);
    assert.equal(body.status, "ok");
  });

  it("rejects inbound without the webhook secret", async () => {
    const response = await worker.fetch(
      new Request("https://ben-support-desk.test/inbound", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(inboundPayload()),
      }),
      makeEnv(createTicketStore())
    );
    const { status, body } = await jsonOf(response);
    assert.equal(status, 401);
    assert.equal(body.error, "unauthorized");
  });

  it("creates a pending ticket, matches refund-trial, and posts to Slack", async () => {
    const store = createTicketStore();
    const response = await worker.fetch(
      new Request(`https://ben-support-desk.test/inbound?secret=${WEBHOOK_SECRET}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(inboundPayload()),
      }),
      makeEnv(store)
    );
    const { status, body } = await jsonOf(response);
    assert.equal(status, 200);
    assert.equal(body.status, "ok");
    assert.equal(body.playbook_id, "refund-trial");
    const ticket = store.byId.get(body.ticket_id);
    assert.equal(ticket.status, "pending");
    assert.equal(ticket.from_email, "sam@example.com");
    assert.equal(slackPosts.length, 1);
    assert.equal(slackPosts[0].channel, "C0BV6LP1X8F");
    const actions = slackPosts[0].blocks[1].elements.map((el) => el.action_id);
    assert.deepEqual(actions, ["approve_ticket", "reject_ticket", "escalate_engineer"]);
    assert.equal(ticket.slack_message_ts, "1.000");
  });

  it("dedupes inbound by Postmark MessageID", async () => {
    const store = createTicketStore();
    const env = makeEnv(store);
    const req = () =>
      new Request(`https://ben-support-desk.test/inbound?secret=${WEBHOOK_SECRET}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(inboundPayload()),
      });
    const first = await jsonOf(await worker.fetch(req(), env));
    const second = await jsonOf(await worker.fetch(req(), env));
    assert.equal(first.body.status, "ok");
    assert.equal(second.status, 200);
    assert.equal(second.body.status, "duplicate");
    assert.equal(second.body.ticket_id, first.body.ticket_id);
    assert.equal(store.byId.size, 1);
  });

  it("auto-posts ENGINEER_HANDOFF for bug-report playbooks", async () => {
    const store = createTicketStore();
    const response = await worker.fetch(
      new Request(`https://ben-support-desk.test/inbound?secret=${WEBHOOK_SECRET}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(
          inboundPayload({
            MessageID: "pm-bug",
            Subject: "App crash",
            TextBody: "Ben crashes when I open a bill",
          })
        ),
      }),
      makeEnv(store)
    );
    const { body } = await jsonOf(response);
    assert.equal(body.playbook_id, "bug-report");
    assert.equal(slackPosts.length, 3);
    assert.equal(slackPosts[0].channel, "C0BV6LP1X8F");
    assert.equal(slackPosts[1].channel, "C0C0CAR1P9S");
    assert.ok(slackPosts[1].text.includes("ENGINEER_HANDOFF"));
    assert.ok(!slackPosts[1].text.includes("@Cursor"));
    assert.ok(slackPosts[2].text.includes("sent to Engineer"));
    const ticket = store.byId.get(body.ticket_id);
    assert.equal(ticket.engineer_message_ts, "2.000");
  });

  it("approves a pending ticket and sends Postmark outbound", async () => {
    const store = createTicketStore();
    const env = makeEnv(store);
    const created = await jsonOf(
      await worker.fetch(
        new Request(`https://ben-support-desk.test/inbound?secret=${WEBHOOK_SECRET}`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(inboundPayload()),
        }),
        env
      )
    );
    const payload = new URLSearchParams({
      payload: JSON.stringify({
        actions: [{ action_id: "approve_ticket", value: created.body.ticket_id }],
      }),
    }).toString();
    const signed = await signSlackBody(payload);
    const response = await worker.fetch(
      new Request("https://ben-support-desk.test/slack/interactions", {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded",
          "x-slack-signature": signed.signature,
          "x-slack-request-timestamp": signed.timestamp,
        },
        body: payload,
      }),
      env
    );
    const { status, body } = await jsonOf(response);
    assert.equal(status, 200);
    assert.equal(body.status, "sent");
    assert.equal(store.byId.get(created.body.ticket_id).status, "sent");
    assert.equal(postmarkSends.length, 1);
    assert.equal(postmarkSends[0].From, "support@benandbill.app");
    assert.equal(postmarkSends[0].To, "sam@example.com");
  });

  it("rejects Slack interactions with a bad signature", async () => {
    const response = await worker.fetch(
      new Request("https://ben-support-desk.test/slack/interactions", {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded",
          "x-slack-signature": "v0=deadbeef",
          "x-slack-request-timestamp": String(Math.floor(Date.now() / 1000)),
        },
        body: "payload=%7B%7D",
      }),
      makeEnv(createTicketStore())
    );
    const { status } = await jsonOf(response);
    assert.equal(status, 401);
  });
});
