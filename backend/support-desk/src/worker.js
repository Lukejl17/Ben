// Ben support desk: support@ → draft → Slack Approve/Reject → send.
//
// Intake: Postmark inbound webhook (Gmail forwards a copy from Workspace).
// Desk: Slack #ben-support with Approve / Reject buttons.
// Memory: D1 playbook_entries (seed + approved upserts).
// Outbound: Postmark From support@benandbill.app after Approve only.

import {
  SEED_PLAYBOOK,
  buildDraft,
  snippetForSlack,
  playbookEntryFromApproval,
} from "./draft.js";
import { parseInbound, sendSupportReply } from "./mail.js";
import {
  postTicketDraft,
  updateTicketMessage,
  postDigest,
  verifySlackSignature,
} from "./slack.js";

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, service: "ben-support-desk" });
      }

      if (request.method === "POST" && url.pathname === "/inbound") {
        if (!secretMatches(url.searchParams.get("secret"), env.WEBHOOK_SECRET)) {
          return json({ error: "unauthorized" }, 401);
        }
        await ensurePlaybookSeeded(env);
        return handleInbound(await request.json(), env, ctx);
      }

      if (request.method === "POST" && url.pathname === "/slack/interactions") {
        return handleSlackInteraction(request, env);
      }

      if (request.method === "POST" && url.pathname === "/cron/weekly-digest") {
        if (!secretMatches(url.searchParams.get("secret"), env.WEBHOOK_SECRET)) {
          return json({ error: "unauthorized" }, 401);
        }
        return runWeeklyDigest(env);
      }

      return json({ error: "not found" }, 404);
    } catch (error) {
      console.log(JSON.stringify({ level: "error", message: String(error?.message ?? error) }));
      return json({ error: "internal error" }, 500);
    }
  },

  // Wrangler cron: weekly digest (see wrangler.toml triggers).
  async scheduled(_event, env, _ctx) {
    try {
      await runWeeklyDigest(env);
    } catch (error) {
      console.log(JSON.stringify({ level: "error", message: String(error?.message ?? error) }));
    }
  },
};

async function handleInbound(message, env, ctx) {
  const parsed = parseInbound(message, env.POSTMARK_INBOUND_LOCAL ?? "support-desk");
  if (!parsed.ok) {
    return json({ status: parsed.reason }, 200);
  }

  const entries = await loadPlaybook(env);
  const drafted = buildDraft({
    subject: parsed.subject,
    body: parsed.bodyPlain,
    entries,
  });

  const now = new Date().toISOString();
  const id = crypto.randomUUID();
  const ticket = {
    id,
    created_at: now,
    updated_at: now,
    status: "pending_approval",
    customer_email: parsed.customerEmail,
    customer_name: parsed.customerName,
    subject: parsed.subject,
    body_plain: parsed.bodyPlain,
    body_snippet: snippetForSlack(parsed.bodyPlain),
    topic: drafted.topic,
    draft_reply: drafted.draft,
    playbook_id: drafted.playbookId,
    slack_ts: null,
    slack_channel: null,
    postmark_message_id: parsed.postmarkMessageId,
    outbound_message_id: null,
  };

  await env.DB.prepare(
    `INSERT INTO tickets (
      id, created_at, updated_at, status, customer_email, customer_name,
      subject, body_plain, body_snippet, topic, draft_reply, playbook_id,
      slack_ts, slack_channel, postmark_message_id, outbound_message_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      ticket.id,
      ticket.created_at,
      ticket.updated_at,
      ticket.status,
      ticket.customer_email,
      ticket.customer_name,
      ticket.subject,
      ticket.body_plain,
      ticket.body_snippet,
      ticket.topic,
      ticket.draft_reply,
      ticket.playbook_id,
      null,
      null,
      ticket.postmark_message_id,
      null
    )
    .run();

  await logEvent(env, id, "received", drafted.playbookId ?? "no-match");

  if (drafted.playbookId) {
    await env.DB.prepare(
      "UPDATE playbook_entries SET hit_count = hit_count + 1, updated_at = ? WHERE id = ?"
    )
      .bind(now, drafted.playbookId)
      .run();
  }

  ctx.waitUntil(
    (async () => {
      const posted = await postTicketDraft(env, ticket);
      await env.DB.prepare(
        "UPDATE tickets SET slack_ts = ?, slack_channel = ?, updated_at = ? WHERE id = ?"
      )
        .bind(posted.ts, posted.channel, new Date().toISOString(), id)
        .run();
    })()
  );

  return json({ status: "ok", ticketId: id, topic: drafted.topic }, 200);
}

async function handleSlackInteraction(request, env) {
  const rawBody = await request.text();
  const valid = await verifySlackSignature(env, request, rawBody);
  if (!valid) return json({ error: "invalid signature" }, 401);

  const params = new URLSearchParams(rawBody);
  const payload = JSON.parse(params.get("payload") ?? "{}");

  if (payload.type === "block_actions") {
    const action = payload.actions?.[0];
    const ticketId = action?.value;
    const actionId = action?.action_id;
    const user = payload.user?.username ?? payload.user?.name ?? "luke";

    if (!ticketId || !actionId) return json({ ok: true });

    if (actionId === "approve") {
      // Thread edits: latest "edit: …" in the thread overrides draft.
      const edited = await latestEditInThread(env, payload);
      await approveTicket(env, ticketId, user, edited);
    } else if (actionId === "reject") {
      await rejectTicket(env, ticketId, user);
    }
    return new Response("", { status: 200 });
  }

  return json({ ok: true });
}

async function latestEditInThread(env, payload) {
  const channel = payload.channel?.id;
  const ts = payload.message?.ts;
  if (!channel || !ts || !env.SLACK_BOT_TOKEN) return null;

  const url = new URL("https://slack.com/api/conversations.replies");
  url.searchParams.set("channel", channel);
  url.searchParams.set("ts", ts);
  url.searchParams.set("limit", "50");
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${env.SLACK_BOT_TOKEN}` },
  });
  const data = await res.json();
  if (!data.ok || !Array.isArray(data.messages)) return null;

  for (let i = data.messages.length - 1; i >= 0; i--) {
    const text = String(data.messages[i].text ?? "").trim();
    const match = text.match(/^edit:\s*([\s\S]+)$/i);
    if (match) return match[1].trim();
  }
  return null;
}

async function approveTicket(env, ticketId, user, editedBody) {
  const ticket = await env.DB.prepare("SELECT * FROM tickets WHERE id = ?")
    .bind(ticketId)
    .first();
  if (!ticket || ticket.status !== "pending_approval") return;

  const replyBody = editedBody?.trim() || ticket.draft_reply;
  const outboundId = await sendSupportReply(env, {
    to: ticket.customer_email,
    subject: ticket.subject,
    body: replyBody,
    inReplyTo: ticket.postmark_message_id,
  });

  const now = new Date().toISOString();
  await env.DB.prepare(
    `UPDATE tickets SET status = ?, draft_reply = ?, outbound_message_id = ?, updated_at = ?
     WHERE id = ?`
  )
    .bind("sent", replyBody, outboundId, now, ticketId)
    .run();

  await logEvent(env, ticketId, "approved", user);

  // Phase 2: learn from approvals that weren't pure seed hits, or were edited.
  const shouldUpsert =
    Boolean(editedBody?.trim()) || !ticket.playbook_id || ticket.topic === "other";
  if (shouldUpsert) {
    await upsertPlaybookFromApproval(env, {
      topic: ticket.topic,
      subject: ticket.subject,
      draftReply: replyBody,
    });
  } else if (ticket.playbook_id) {
    await env.DB.prepare(
      "UPDATE playbook_entries SET hit_count = hit_count + 1, updated_at = ? WHERE id = ?"
    )
      .bind(now, ticket.playbook_id)
      .run();
  }

  await updateTicketMessage(
    env,
    ticket,
    `Sent by *${user}* · From ${env.SUPPORT_FROM_EMAIL}`
  );
}

async function rejectTicket(env, ticketId, user) {
  const ticket = await env.DB.prepare("SELECT * FROM tickets WHERE id = ?")
    .bind(ticketId)
    .first();
  if (!ticket || ticket.status !== "pending_approval") return;

  const now = new Date().toISOString();
  await env.DB.prepare("UPDATE tickets SET status = ?, updated_at = ? WHERE id = ?")
    .bind("rejected", now, ticketId)
    .run();
  await logEvent(env, ticketId, "rejected", user);
  await updateTicketMessage(env, ticket, `Rejected by *${user}* — no mail sent.`);
}

async function upsertPlaybookFromApproval(env, { topic, subject, draftReply }) {
  const entry = playbookEntryFromApproval({ topic, subject, draftReply });
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO playbook_entries
      (id, topic, tags, title, body, hit_count, created_at, updated_at, source)
     VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)`
  )
    .bind(
      entry.id,
      entry.topic,
      entry.tags,
      entry.title,
      entry.body,
      now,
      now,
      entry.source
    )
    .run();
  await logEvent(env, entry.id, "playbook_upsert", entry.topic);
}

async function ensurePlaybookSeeded(env) {
  const row = await env.DB.prepare(
    "SELECT COUNT(*) AS c FROM playbook_entries WHERE source = 'seed'"
  ).first();
  if (row && Number(row.c) > 0) return;

  const now = new Date().toISOString();
  for (const entry of SEED_PLAYBOOK) {
    await env.DB.prepare(
      `INSERT OR IGNORE INTO playbook_entries
        (id, topic, tags, title, body, hit_count, created_at, updated_at, source)
       VALUES (?, ?, ?, ?, ?, 0, ?, ?, 'seed')`
    )
      .bind(entry.id, entry.topic, entry.tags, entry.title, entry.body, now, now)
      .run();
  }
}

async function loadPlaybook(env) {
  const { results } = await env.DB.prepare(
    "SELECT id, topic, tags, title, body FROM playbook_entries"
  ).all();
  if (results?.length) return results;
  return SEED_PLAYBOOK;
}

async function runWeeklyDigest(env) {
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const topics = await env.DB.prepare(
    `SELECT topic, COUNT(*) AS c FROM tickets
     WHERE created_at >= ? GROUP BY topic ORDER BY c DESC LIMIT 8`
  )
    .bind(weekAgo)
    .all();
  const pending = await env.DB.prepare(
    "SELECT COUNT(*) AS c FROM tickets WHERE status = 'pending_approval'"
  ).first();
  const sent = await env.DB.prepare(
    `SELECT COUNT(*) AS c FROM tickets WHERE status = 'sent' AND updated_at >= ?`
  )
    .bind(weekAgo)
    .first();
  const learned = await env.DB.prepare(
    `SELECT COUNT(*) AS c FROM playbook_entries
     WHERE source = 'approved' AND created_at >= ?`
  )
    .bind(weekAgo)
    .first();

  const topicLines = (topics.results ?? []).map(
    (row) => `• ${row.topic ?? "other"} — ${row.c}`
  );
  const lines = [
    `*Last 7 days*`,
    `Sent: ${sent?.c ?? 0} · Still pending: ${pending?.c ?? 0} · Playbook adds: ${learned?.c ?? 0}`,
    "",
    "*Topics*",
    ...(topicLines.length ? topicLines : ["• (none yet)"]),
  ];
  await postDigest(env, lines);
  return json({ ok: true, topics: topics.results ?? [] });
}

async function logEvent(env, ticketId, kind, detail) {
  await env.DB.prepare(
    "INSERT INTO ticket_events (ticket_id, created_at, kind, detail) VALUES (?, ?, ?, ?)"
  )
    .bind(ticketId, new Date().toISOString(), kind, detail ?? null)
    .run();
}

function secretMatches(provided, expected) {
  if (!expected || !provided) return false;
  if (provided.length !== expected.length) return false;
  let out = 0;
  for (let i = 0; i < provided.length; i++) {
    out |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return out === 0;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
