/** Postmark inbound parse + outbound send. */

export function parseInbound(message, expectedLocalPart) {
  const to = (message.ToFull?.[0]?.Email ?? message.To ?? "").toLowerCase();
  const local = to.split("@")[0] ?? "";
  if (expectedLocalPart && local !== expectedLocalPart.toLowerCase()) {
    // Also accept mail whose original To was support@ (forwarded) — Postmark
    // may put the forward address in To and original in Headers.
    const original = originalToAddress(message);
    if (!original.includes("support@benandbill.app") && local !== "support") {
      return { ok: false, reason: "unroutable" };
    }
  }

  const fromEmail = (
    message.FromFull?.Email ??
    message.From ??
    ""
  ).toLowerCase();
  const fromName = message.FromFull?.Name ?? message.FromName ?? null;
  const subject = (message.Subject ?? "(no subject)").slice(0, 500);
  const body =
    message.TextBody ??
    stripHtml(message.HtmlBody ?? "") ??
    "";
  const messageId = message.MessageID ?? message.MessageId ?? null;

  if (!fromEmail || !body.trim()) {
    return { ok: false, reason: "empty" };
  }

  return {
    ok: true,
    customerEmail: fromEmail.slice(0, 320),
    customerName: fromName ? String(fromName).slice(0, 200) : null,
    subject,
    bodyPlain: String(body).slice(0, 20_000),
    postmarkMessageId: messageId ? String(messageId).slice(0, 200) : null,
  };
}

function originalToAddress(message) {
  const headers = message.Headers ?? [];
  for (const header of headers) {
    const name = (header.Name ?? "").toLowerCase();
    if (name === "x-forwarded-to" || name === "x-original-to" || name === "delivered-to") {
      return String(header.Value ?? "").toLowerCase();
    }
  }
  return "";
}

function stripHtml(html) {
  return String(html)
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

export async function sendSupportReply(env, { to, subject, body, inReplyTo }) {
  const token = env.POSTMARK_SERVER_TOKEN;
  if (!token) throw new Error("POSTMARK_SERVER_TOKEN missing");

  const payload = {
    From: `${env.SUPPORT_FROM_NAME ?? "Ben Support"} <${env.SUPPORT_FROM_EMAIL}>`,
    To: to,
    Subject: subject.startsWith("Re:") ? subject : `Re: ${subject}`,
    TextBody: body,
    MessageStream: "outbound",
  };
  if (inReplyTo) {
    payload.Headers = [{ Name: "In-Reply-To", Value: inReplyTo }];
  }

  const res = await fetch("https://api.postmarkapp.com/email", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-Postmark-Server-Token": token,
    },
    body: JSON.stringify(payload),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`postmark send failed: ${data.Message ?? res.status}`);
  }
  return data.MessageID ?? null;
}
