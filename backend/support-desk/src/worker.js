// Ben support desk: inbound support emails → playbook draft → Slack approval → Postmark reply.
//
// Distinct from ben-email-in (bill attachments). Own webhook secret, D1, and Postmark stream.
//
// Routes:
//   POST /inbound?secret=...     Postmark inbound webhook
//   POST /slack/interactions     Slack interactive components (Approve / Reject)

import { inboundSearchText, matchPlaybook, renderDraft } from "./playbooks.js";
import { sendSupportReply } from "./postmark.js";
import { postTicketMessage, updateTicketMessage, verifySlackSignature } from "./slack.js";

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return json({ status: "ok" });
      }

      if (request.method === "POST" && url.pathname === "/inbound") {
        if (!secretMatches(url.searchParams.get("secret"), env.WEBHOOK_SECRET)) {
          return json({ error: "unauthorized" }, 401);
        }
        return handleInbound(await request.json(), env);
      }

      if (request.method === "POST" && url.pathname === "/slack/interactions") {
        const rawBody = await request.text();
        if (!(await verifySlackSignature(request, env.SLACK_SIGNING_SECRET, rawBody))) {
          return json({ error: "invalid signature" }, 401);
        }
        return handleSlackInteraction(rawBody, env);
      }

      return json({ error: "not found" }, 404);
    } catch (error) {
      console.log(JSON.stringify({ level: "error", message: String(error?.message ?? error) }));
      return json({ error: "internal error" }, 500);
    }
  },
};

// ---- Postmark inbound --------------------------------------------------------

async function handleInbound(message, env) {
  const messageId = message.MessageID ?? "";
  if (!messageId) return json({ error: "missing MessageID" }, 400);

  const existing = await env.TICKETS
    .prepare("SELECT id FROM tickets WHERE postmark_message_id = ?")
    .bind(messageId)
    .first();
  if (existing) {
    return json({ status: "duplicate", ticket_id: existing.id }, 200);
  }

  const fromEmail = (
    message.FromFull?.Email ?? parseEmailAddress(message.From) ?? ""
  ).toLowerCase();
  const fromName = message.FromFull?.Name ?? parseDisplayName(message.From) ?? null;
  const subject = message.Subject ?? "(no subject)";
  const bodyText = message.TextBody ?? stripHtml(message.HtmlBody ?? "");
  const messageIdHeader = findHeader(message.Headers, "Message-ID");

  const playbook = matchPlaybook(inboundSearchText(message));
  const draft = renderDraft(playbook, {
    fromName,
    fromEmail,
    originalSubject: subject,
  });

  const ticketId = randomId();
  const now = nowSeconds();

  const ticket = {
    id: ticketId,
    postmark_message_id: messageId,
    from_email: fromEmail,
    from_name: fromName,
    subject,
    body_text: bodyText,
    body_html: message.HtmlBody ?? null,
    message_id_header: messageIdHeader,
    playbook_id: playbook.id,
    draft_subject: draft.subject,
    draft_body: draft.body,
    status: "pending",
    created_at: now,
    updated_at: now,
  };

  await env.TICKETS
    .prepare(
      `INSERT INTO tickets (
        id, postmark_message_id, from_email, from_name, subject,
        body_text, body_html, message_id_header, playbook_id,
        draft_subject, draft_body, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      ticket.id,
      ticket.postmark_message_id,
      ticket.from_email,
      ticket.from_name,
      ticket.subject,
      ticket.body_text,
      ticket.body_html,
      ticket.message_id_header,
      ticket.playbook_id,
      ticket.draft_subject,
      ticket.draft_body,
      ticket.status,
      ticket.created_at,
      ticket.updated_at
    )
    .run();

  if (env.SLACK_BOT_TOKEN && env.SLACK_CHANNEL_ID) {
    try {
      const slack = await postTicketMessage({
        botToken: env.SLACK_BOT_TOKEN,
        channelId: env.SLACK_CHANNEL_ID,
        ticket,
      });
      await env.TICKETS
        .prepare(
          "UPDATE tickets SET slack_channel = ?, slack_message_ts = ?, updated_at = ? WHERE id = ?"
        )
        .bind(slack.channel, slack.ts, nowSeconds(), ticketId)
        .run();
    } catch (error) {
      console.log(
        JSON.stringify({ level: "warn", message: "slack post failed", detail: String(error) })
      );
    }
  }

  return json({ status: "ok", ticket_id: ticketId, playbook_id: playbook.id }, 200);
}

// ---- Slack interactions ------------------------------------------------------

async function handleSlackInteraction(rawBody, env) {
  const params = new URLSearchParams(rawBody);
  const payload = JSON.parse(params.get("payload") ?? "{}");

  const action = payload.actions?.[0];
  if (!action?.value) return json({ ok: true });

  const ticketId = action.value;
  const actionId = action.action_id;

  const ticket = await env.TICKETS
    .prepare("SELECT * FROM tickets WHERE id = ?")
    .bind(ticketId)
    .first();

  if (!ticket) return json({ ok: true });

  if (ticket.status !== "pending" && ticket.status !== "pending_edit") {
    return json({ ok: true, status: ticket.status });
  }

  const now = nowSeconds();

  if (actionId === "reject_ticket") {
    await env.TICKETS
      .prepare("UPDATE tickets SET status = ?, updated_at = ? WHERE id = ?")
      .bind("dismissed", now, ticketId)
      .run();

    if (ticket.slack_channel && ticket.slack_message_ts && env.SLACK_BOT_TOKEN) {
      await updateTicketMessage({
        botToken: env.SLACK_BOT_TOKEN,
        channel: ticket.slack_channel,
        ts: ticket.slack_message_ts,
        ticket,
        statusLabel: "Dismissed",
      });
    }

    return json({ ok: true, status: "dismissed" });
  }

  if (actionId === "approve_ticket") {
    if (!env.POSTMARK_SERVER_TOKEN) {
      return json({ error: "postmark not configured" }, 503);
    }

    const fromEmail = env.SUPPORT_FROM_EMAIL ?? "support@benandbill.app";

    await sendSupportReply({
      serverToken: env.POSTMARK_SERVER_TOKEN,
      fromEmail,
      toEmail: ticket.from_email,
      subject: ticket.draft_subject,
      textBody: ticket.draft_body,
      inReplyTo: ticket.message_id_header,
    });

    await env.TICKETS
      .prepare("UPDATE tickets SET status = ?, updated_at = ? WHERE id = ?")
      .bind("sent", now, ticketId)
      .run();

    if (ticket.slack_channel && ticket.slack_message_ts && env.SLACK_BOT_TOKEN) {
      await updateTicketMessage({
        botToken: env.SLACK_BOT_TOKEN,
        channel: ticket.slack_channel,
        ts: ticket.slack_message_ts,
        ticket,
        statusLabel: "Sent",
      });
    }

    return json({ ok: true, status: "sent" });
  }

  return json({ ok: true });
}

// ---- Helpers -----------------------------------------------------------------

function parseEmailAddress(from) {
  const match = (from ?? "").match(/<([^>]+)>/);
  return match?.[1] ?? from;
}

function parseDisplayName(from) {
  const match = (from ?? "").match(/^([^<]+)</);
  return match?.[1]?.trim().replace(/^"|"$/g, "") ?? null;
}

function findHeader(headers, name) {
  const header = (headers ?? []).find((h) => h.Name?.toLowerCase() === name.toLowerCase());
  return header?.Value ?? null;
}

function stripHtml(html) {
  return (html ?? "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .trim();
}

function randomId() {
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
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
