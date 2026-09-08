// Postmark outbound email for approved support replies.

const POSTMARK_API = "https://api.postmarkapp.com/email";

export async function sendSupportReply({ token, from, to, subject, textBody, inReplyTo }) {
  const headers = {
    "X-Postmark-Server-Token": token,
    "Content-Type": "application/json",
    Accept: "application/json",
  };

  const body = {
    From: from,
    To: to,
    Subject: subject,
    TextBody: textBody,
    MessageStream: "outbound",
  };

  if (inReplyTo) {
    body.Headers = [
      { Name: "In-Reply-To", Value: inReplyTo },
      { Name: "References", Value: inReplyTo },
    ];
  }

  const response = await fetch(POSTMARK_API, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const detail = data.Message ?? data.ErrorCode ?? response.status;
    throw new Error(`Postmark send failed: ${detail}`);
  }
  return data;
}

/** Extract Message-ID from Postmark inbound Headers array. */
export function messageIdFromInbound(message) {
  const headers = message.Headers ?? [];
  for (const header of headers) {
    if ((header.Name ?? "").toLowerCase() === "message-id") {
      return header.Value ?? null;
    }
  }
  return null;
}

/** Parse display name and email from Postmark From field. */
export function parseFromAddress(from) {
  const raw = (from ?? "").trim();
  const bracketed = raw.match(/^(.+?)\s*<([^>]+)>$/);
  if (bracketed) {
    return { name: bracketed[1].replace(/^"|"$/g, "").trim(), email: bracketed[2].trim() };
  }
  if (raw.includes("@")) return { name: "", email: raw };
  return { name: raw, email: "" };
}
