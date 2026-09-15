// Postmark outbound email for approved support replies.

const POSTMARK_API = "https://api.postmarkapp.com/email";

export async function sendSupportReply({
  serverToken,
  fromEmail,
  toEmail,
  subject,
  textBody,
  inReplyTo,
}) {
  const headers = [];
  if (inReplyTo) {
    headers.push({ Name: "In-Reply-To", Value: inReplyTo });
    headers.push({ Name: "References", Value: inReplyTo });
  }

  const response = await fetch(POSTMARK_API, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-postmark-server-token": serverToken,
    },
    body: JSON.stringify({
      From: fromEmail,
      To: toEmail,
      Subject: subject,
      TextBody: textBody,
      MessageStream: "outbound",
      Headers: headers.length ? headers : undefined,
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Postmark send failed: ${data.Message ?? response.status}`);
  }
  return data;
}
