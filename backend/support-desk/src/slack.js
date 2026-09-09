// Slack signature verification and chat.postMessage helpers.

import { timingSafeEqualString } from "./crypto.js";

const SLACK_API = "https://slack.com/api";

/** Verify Slack request signature (v0). Returns false on mismatch or stale timestamp. */
export async function verifySlackSignature(request, signingSecret, rawBody) {
  if (!signingSecret) return false;

  const signature = request.headers.get("x-slack-signature") ?? "";
  const timestamp = request.headers.get("x-slack-request-timestamp") ?? "";

  if (!signature.startsWith("v0=") || !timestamp) return false;

  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (!Number.isFinite(age) || age > 60 * 5) return false;

  const base = `v0:${timestamp}:${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(signingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(base));
  const expected = `v0=${toHex(mac)}`;

  return timingSafeEqualString(signature, expected);
}

export async function postTicketMessage({ botToken, channelId, ticket }) {
  const preview = truncate(ticket.body_text ?? ticket.draft_body, 400);
  const text = [
    `*Support ticket* \`${ticket.id}\``,
    `*From:* ${formatFrom(ticket)}`,
    `*Subject:* ${ticket.subject}`,
    `*Playbook:* ${ticket.playbook_id}`,
    "",
    `*Inbound:*`,
    preview,
    "",
    `*Draft reply:*`,
    `_${ticket.draft_subject}_`,
    truncate(ticket.draft_body, 600),
  ].join("\n");

  const response = await slackApi("chat.postMessage", botToken, {
    channel: channelId,
    text: `Support ticket ${ticket.id}`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
      {
        type: "actions",
        block_id: `ticket_${ticket.id}`,
        elements: [
          {
            type: "button",
            text: { type: "plain_text", text: "Approve" },
            style: "primary",
            action_id: "approve_ticket",
            value: ticket.id,
          },
          {
            type: "button",
            text: { type: "plain_text", text: "Reject" },
            style: "danger",
            action_id: "reject_ticket",
            value: ticket.id,
          },
          {
            type: "button",
            text: { type: "plain_text", text: "Send to Engineer" },
            action_id: "escalate_engineer",
            value: ticket.id,
          },
        ],
      },
    ],
  });

  return { channel: response.channel, ts: response.ts };
}

/** Top-level post in #ben-engineering-support-tickets. Do not @cursor. */
export async function postEngineerHandoff({ botToken, channelId, text }) {
  const response = await slackApi("chat.postMessage", botToken, {
    channel: channelId,
    text,
  });
  return { channel: response.channel, ts: response.ts };
}

export async function postThreadNote({ botToken, channel, threadTs, text }) {
  await slackApi("chat.postMessage", botToken, {
    channel,
    thread_ts: threadTs,
    text,
  });
}

export async function updateTicketMessage({ botToken, channel, ts, ticket, statusLabel }) {
  const text = [
    `*Support ticket* \`${ticket.id}\` · *${statusLabel}*`,
    `*From:* ${formatFrom(ticket)}`,
    `*Subject:* ${ticket.subject}`,
    `*Playbook:* ${ticket.playbook_id}`,
  ].join("\n");

  await slackApi("chat.update", botToken, {
    channel,
    ts,
    text,
    blocks: [{ type: "section", text: { type: "mrkdwn", text } }],
  });
}

async function slackApi(method, botToken, body) {
  const response = await fetch(`${SLACK_API}/${method}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${botToken}`,
      "content-type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  if (!data.ok) {
    throw new Error(`Slack ${method} failed: ${data.error ?? response.status}`);
  }
  return data;
}

function formatFrom(ticket) {
  if (ticket.from_name) return `${ticket.from_name} <${ticket.from_email}>`;
  return ticket.from_email;
}

function truncate(text, max) {
  const value = (text ?? "").trim();
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}

function toHex(buffer) {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

