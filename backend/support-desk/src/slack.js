/** Slack Block Kit + API helpers for the support desk. */

export function ticketBlocks(ticket) {
  const topic = ticket.topic ?? "other";
  const match = ticket.playbook_id
    ? `Playbook: ${ticket.playbook_id}`
    : "No playbook match — review carefully";
  return [
    {
      type: "header",
      text: { type: "plain_text", text: "Support draft", emoji: false },
    },
    {
      type: "section",
      fields: [
        { type: "mrkdwn", text: `*From*\n${ticket.customer_email}` },
        { type: "mrkdwn", text: `*Topic*\n${topic}` },
      ],
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `*Subject*\n${ticket.subject}\n\n*Snippet*\n>${ticket.body_snippet.replace(/\n/g, "\n>")}`,
      },
    },
    {
      type: "section",
      text: { type: "mrkdwn", text: `*Draft reply*\n\`\`\`${ticket.draft_reply}\`\`\`` },
    },
    {
      type: "context",
      elements: [{ type: "mrkdwn", text: `${match} · id \`${ticket.id}\`` }],
    },
    {
      type: "actions",
      block_id: `ticket_actions_${ticket.id}`,
      elements: [
        {
          type: "button",
          action_id: "approve",
          text: { type: "plain_text", text: "Approve & send" },
          style: "primary",
          value: ticket.id,
        },
        {
          type: "button",
          action_id: "reject",
          text: { type: "plain_text", text: "Reject" },
          style: "danger",
          value: ticket.id,
        },
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: "To edit: reply in this thread with `edit:` followed by the full reply text, then press Approve.",
        },
      ],
    },
  ];
}

export async function postTicketDraft(env, ticket) {
  const res = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_BOT_TOKEN}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel: env.SLACK_CHANNEL_ID,
      text: `Support draft: ${ticket.subject}`,
      blocks: ticketBlocks(ticket),
    }),
  });
  const data = await res.json();
  if (!data.ok) {
    throw new Error(`slack post failed: ${data.error ?? res.status}`);
  }
  return { ts: data.ts, channel: data.channel };
}

export async function updateTicketMessage(env, ticket, statusLine) {
  if (!ticket.slack_ts || !ticket.slack_channel) return;
  await fetch("https://slack.com/api/chat.update", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_BOT_TOKEN}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel: ticket.slack_channel,
      ts: ticket.slack_ts,
      text: statusLine,
      blocks: [
        {
          type: "section",
          text: { type: "mrkdwn", text: statusLine },
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: `*${ticket.subject}* · ${ticket.customer_email} · \`${ticket.id}\``,
            },
          ],
        },
      ],
    }),
  });
}

export async function postDigest(env, lines) {
  await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_BOT_TOKEN}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel: env.SLACK_CHANNEL_ID,
      text: "Support weekly digest",
      blocks: [
        {
          type: "header",
          text: { type: "plain_text", text: "Support weekly digest" },
        },
        {
          type: "section",
          text: { type: "mrkdwn", text: lines.join("\n") },
        },
      ],
    }),
  });
}

/** Verify Slack signing secret (v0). */
export async function verifySlackSignature(env, request, rawBody) {
  const timestamp = request.headers.get("x-slack-request-timestamp");
  const signature = request.headers.get("x-slack-signature");
  if (!timestamp || !signature || !env.SLACK_SIGNING_SECRET) return false;
  const age = Math.abs(Date.now() / 1000 - Number(timestamp));
  if (age > 60 * 5) return false;
  const base = `v0:${timestamp}:${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env.SLACK_SIGNING_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(base));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  const expected = `v0=${hex}`;
  return timingSafeEqual(expected, signature);
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}
