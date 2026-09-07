# Support desk — human setup (Phase 0)

Ops layer beside Ben. Customers mail **support@benandbill.app**; an agent drafts;
you Approve/Edit/Reject in Slack; only then does a reply send.

Bill forwarding (`bills-*@in.benandbill.app`) is a **different pipe** — do not mix.

## 1. Google Workspace mailbox

1. In Google Workspace Admin, create user (or group with shared inbox):
   - Address: `support@benandbill.app`
   - Display name: `Ben Support`
2. Sign in once to Gmail as that user; turn on 2FA.
3. **Auto-forward** a copy of every inbound message to the Postmark inbound
   address from §3 (so the Worker sees mail while you still read it in Gmail).
   - Gmail → Settings → Forwarding → add the Postmark address → confirm.
   - Keep “keep Ben’s copy in the Inbox”.
4. DNS (apex `benandbill.app`): ensure MX for Google Workspace is correct for
   human mail. Do **not** point apex MX at Postmark — only the forward target
   / `in.benandbill.app` subdomain talks to Postmark.
5. Send yourself a test: `support@benandbill.app` → appears in Gmail **and**
   hits the Worker `/inbound` (check Cloudflare logs).

## 2. Slack ops desk

Step-by-step click path (while Workspace is cooking): **[SLACK.md](SLACK.md)**.

Summary:

1. Private channel `#ben-support` → copy channel ID (`C…`).
2. [api.slack.com/apps](https://api.slack.com/apps) → From scratch → **Ben Support Desk**.
3. Bot scopes: `chat:write`, `channels:history`, `groups:history`, `reactions:write`.
4. Install → copy `xoxb-…` + Signing Secret → `/invite` bot into the channel.
5. Interactivity URL comes **after** Worker deploy (we paste it then).

## 3. Postmark (inbound + outbound)

1. Inbound stream: accept mail for a forward address, e.g.
   `support-desk@in.benandbill.app` (same MX family as bill mail is fine —
   the Worker routes by local-part `support-desk`).
2. Inbound webhook URL:
   `https://<worker-host>/inbound?secret=<WEBHOOK_SECRET>`
3. Outbound: verify sender `support@benandbill.app` (DKIM/SPF as Postmark guides)
   so approved replies leave From: Ben Support &lt;support@benandbill.app&gt;.

## 4. Deploy the Worker

```bash
cd backend/support-desk
npx wrangler login
npx wrangler d1 create ben-support
# paste database_id into wrangler.toml
npx wrangler d1 execute ben-support --file=./schema.sql --remote
npx wrangler secret put WEBHOOK_SECRET
npx wrangler secret put SLACK_BOT_TOKEN
npx wrangler secret put SLACK_SIGNING_SECRET
npx wrangler secret put POSTMARK_SERVER_TOKEN
npx wrangler secret put LLM_API_KEY   # optional — playbook-only drafts work without it
npx wrangler deploy
```

Set non-secret vars in `wrangler.toml` / dashboard:

- `SLACK_CHANNEL_ID`
- `SUPPORT_FROM_EMAIL` = `support@benandbill.app`
- `SUPPORT_FROM_NAME` = `Ben Support`
- `POSTMARK_INBOUND_LOCAL` = `support-desk` (local-part before @)

## 5. Smoke test

1. Email `support@benandbill.app` with subject “Test: reminder did not fire”.
2. Slack `#ben-support` shows a draft card.
3. Click **Approve** → reply lands in the customer thread From support@.
4. Click **Reject** on another test → no outbound mail; ticket closed.
5. Approve a novel question → new row in D1 `playbook_entries` (Phase 2).

## Privacy

- Slack cards include subject + short plain-text snippet only.
- Strip/omit long payment refs and attachments from Slack bodies.
- Never auto-send in v1 without Approve.
