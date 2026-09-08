// Slack request verification and Block Kit helpers.

const SLACK_API = "https://slack.com/api";

/** Verify Slack signing secret per https://api.slack.com/authentication/verifying-requests-from-slack */
export async function verifySlackRequest(request, signingSecret, rawBody) {
  if (!signingSecret) return false;

  const timestamp = request.headers.get("x-slack-request-timestamp") ?? "";
  const signature = request.headers.get("x-slack-signature") ?? "";
  if (!timestamp || !signature) return false;

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

  return timingSafeEqual(signature, expected);
}

export async function postSupportTicketMessage({ token, channel, ticket }) {
  const text = `Support from ${ticket.from_email}: ${ticket.subject}`;
  const blocks = buildTicketBlocks(ticket);

  const response = await slackApi(token, "chat.postMessage", {
    channel,
    text,
    blocks,
  });
  return response;
}

export async function updateTicketMessage({ token, channel, messageTs, ticket, statusNote }) {
  const text = `Support from ${ticket.from_email}: ${ticket.subject} — ${statusNote}`;
  const blocks = buildTicketBlocks(ticket, statusNote);

  return slackApi(token, "chat.update", {
    channel,
    ts: messageTs,
    text,
    blocks,
  });
}

function buildTicketBlocks(ticket, statusNote = null) {
  const preview = truncate(ticket.draft_body, 1200);
  const blocks = [
    {
      type: "header",
      text: { type: "plain_text", text: "Ben support ticket", emoji: false },
    },
    {
      type: "section",
      fields: [
        { type: "mrkdwn", text: `*From:*\n${ticket.from_email}` },
        { type: "mrkdwn", text: `*Playbook:*\n${ticket.playbook_id}` },
        { type: "mrkdwn", text: `*Subject:*\n${ticket.subject}` },
        {
          type: "mrkdwn",
          text: `*Status:*\n${statusNote ?? ticket.status}`,
        },
      ],
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `*Draft reply*\n\`\`\`${preview}\`\`\``,
      },
    },
  ];

  if (!statusNote || statusNote === "pending") {
    blocks.push({
      type: "actions",
      block_id: `ticket_${ticket.id}`,
      elements: [
        {
          type: "button",
          text: { type: "plain_text", text: "Approve", emoji: false },
          style: "primary",
          action_id: "support_approve",
          value: ticket.id,
        },
        {
          type: "button",
          text: { type: "plain_text", text: "Reject", emoji: false },
          style: "danger",
          action_id: "support_reject",
          value: ticket.id,
        },
        {
          type: "button",
          text: { type: "plain_text", text: "Edit", emoji: false },
          action_id: "support_edit",
          value: ticket.id,
        },
      ],
    });
  }

  return blocks;
}

async function slackApi(token, method, body) {
  const response = await fetch(`${SLACK_API}/${method}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
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

function truncate(text, max) {
  const value = (text ?? "").trim();
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}

function toHex(buffer) {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a, b) {
  const enc = new TextEncoder();
  const left = enc.encode(a);
  const right = enc.encode(b);
  if (left.byteLength !== right.byteLength) return false;
  return crypto.subtle.timingSafeEqual(left, right);
}
