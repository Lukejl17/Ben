// Ben support desk: inbound support mail → D1 ticket → Slack approval → Postmark reply.
//
// Mail flow:
//   support@benandbill.app (Gmail) forwards to support-desk@in.benandbill.app
//   Postmark inbound webhooks POST /inbound?secret=WEBHOOK_SECRET
//
// Distinct from ben-email-in (bills-*@in.benandbill.app). Do not share webhook secrets.

import {
  inboundSearchText,
  matchPlaybook,
  renderDraft,
} from "./playbooks.js";
import { messageIdFromInbound, parseFromAddress, sendSupportReply } from "./postmark.js";
import {
  postSupportTicketMessage,
  updateTicketMessage,
  verifySlackRequest,
} from "./slack.js";

const SUPPORT_INBOUND_ADDRESS = "support-desk@in.benandbill.app";

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      const route = `${request.method} ${url.pathname}`;

      if (request.method === "POST" && url.pathname === "/inbound") {
        if (!secretMatches(url.searchParams.get("secret"), env.WEBHOOK_SECRET)) {
          return json({ error: "unauthorized" }, 401);
        }
        return handleInbound(await request.json(), env);
      }

      if (request.method === "POST" && url.pathname === "/slack/interactions") {
        const rawBody = await request.text();
        const verified = await verifySlackRequest(request, env.SLACK_SIGNING_SECRET, rawBody);
        if (!verified) return json({ error: "unauthorized" }, 401);
        return handleSlackInteraction(rawBody, env);
      }

      if (route === "GET /health") {
        return json({ status: "ok", worker: "ben-support-desk" });
      }

      return json({ error: "not found" }, 404);
    } catch (error) {
      console.log(JSON.stringify({ level: "error", message: String(error?.message ?? error) }));
      return json({ error: "internal error" }, 500);
    }
  },
};

// ---- Postmark inbound ------------------------------------------------------

async function handleInbound(message, env) {
  const to = (message.ToFull?.[0]?.Email ?? message.To ?? "").toLowerCase();
  if (!to.includes(SUPPORT_INBOUND_ADDRESS)) {
    console.log(JSON.stringify({ level: "info", message: "dropped unroutable support mail", to }));
    return json({ status: "unroutable" }, 200);
  }

  const postmarkId = message.MessageID ?? "";
  if (!postmarkId) return json({ error: "missing MessageID" }, 400);

  const existing = await env.TICKETS
    .prepare("SELECT id FROM tickets WHERE postmark_message_id = ?")
    .bind(postmarkId)
    .first();
  if (existing) {
    return json({ status: "duplicate", ticketId: existing.id }, 200);
  }

  const from = parseFromAddress(message.From ?? "");
  const subject = (message.Subject ?? "(no subject)").trim();
  const bodyText = message.TextBody ?? "";
  const bodyHtml = message.HtmlBody ?? "";
  const messageIdHeader = messageIdFromInbound(message);

  const playbook = matchPlaybook(inboundSearchText(message));
  const draft = renderDraft(playbook, {
    fromName: from.name,
    fromEmail: from.email,
    originalSubject: subject,
  });

  const ticketId = randomId();
  const now = nowSeconds();

  await env.TICKETS
    .prepare(
      `INSERT INTO tickets (
        id, postmark_message_id, from_email, from_name, subject,
        body_text, body_html, message_id_header, playbook_id,
        draft_subject, draft_body, status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)`
    )
    .bind(
      ticketId,
      postmarkId,
      from.email || (message.From ?? "unknown"),
      from.name || null,
      subject,
      bodyText,
      bodyHtml,
      messageIdHeader,
      draft.playbookId,
      draft.subject,
      draft.body,
      now,
      now
    )
    .run();

  const ticket = {
    id: ticketId,
    from_email: from.email || message.From,
    subject,
    playbook_id: draft.playbookId,
    draft_body: draft.body,
    status: "pending",
  };

  if (env.SLACK_BOT_TOKEN && env.SLACK_CHANNEL_ID) {
    try {
      const slack = await postSupportTicketMessage({
        token: env.SLACK_BOT_TOKEN,
        channel: env.SLACK_CHANNEL_ID,
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
        JSON.stringify({ level: "error", message: "slack post failed", detail: String(error) })
      );
    }
  }

  return json({ status: "ok", ticketId, playbookId: draft.playbookId }, 200);
}

// ---- Slack interactions ----------------------------------------------------

async function handleSlackInteraction(rawBody, env) {
  const params = new URLSearchParams(rawBody);
  const payload = JSON.parse(params.get("payload") ?? "{}");
  const action = payload.actions?.[0];
  if (!action) return json({ ok: true });

  const ticketId = action.value;
  const actionId = action.action_id;

  const ticket = await env.TICKETS
    .prepare("SELECT * FROM tickets WHERE id = ?")
    .bind(ticketId)
    .first();
  if (!ticket) return json({ ok: true });

  if (ticket.status !== "pending" && ticket.status !== "pending_edit") {
    return json({ ok: true, note: "already handled" });
  }

  const now = nowSeconds();

  if (actionId === "support_reject") {
    await env.TICKETS
      .prepare("UPDATE tickets SET status = 'dismissed', updated_at = ? WHERE id = ?")
      .bind(now, ticketId)
      .run();
    await maybeUpdateSlack(env, ticket, "dismissed");
    return json({ ok: true });
  }

  if (actionId === "support_edit") {
    await env.TICKETS
      .prepare("UPDATE tickets SET status = 'pending_edit', updated_at = ? WHERE id = ?")
      .bind(now, ticketId)
      .run();
    await maybeUpdateSlack(env, ticket, "pending_edit — edit draft in D1 or reply in thread, then resend manually");
    return json({ ok: true });
  }

  if (actionId === "support_approve") {
    if (!env.POSTMARK_SERVER_TOKEN) {
      return json({ error: "postmark not configured" }, 503);
    }

    const fromEmail = env.SUPPORT_FROM_EMAIL ?? "support@benandbill.app";

    await sendSupportReply({
      token: env.POSTMARK_SERVER_TOKEN,
      from: fromEmail,
      to: ticket.from_email,
      subject: ticket.draft_subject,
      textBody: ticket.draft_body,
      inReplyTo: ticket.message_id_header,
    });

    await env.TICKETS
      .prepare("UPDATE tickets SET status = 'sent', updated_at = ? WHERE id = ?")
      .bind(now, ticketId)
      .run();

    await maybeUpdateSlack(env, ticket, "sent");
    return json({ ok: true });
  }

  return json({ ok: true });
}

async function maybeUpdateSlack(env, ticket, statusNote) {
  if (!env.SLACK_BOT_TOKEN || !ticket.slack_channel || !ticket.slack_message_ts) return;

  const updated = { ...ticket, status: statusNote };
  try {
    await updateTicketMessage({
      token: env.SLACK_BOT_TOKEN,
      channel: ticket.slack_channel,
      messageTs: ticket.slack_message_ts,
      ticket: updated,
      statusNote,
    });
  } catch (error) {
    console.log(
      JSON.stringify({ level: "error", message: "slack update failed", detail: String(error) })
    );
  }
}

// ---- Helpers ---------------------------------------------------------------

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
