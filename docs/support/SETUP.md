# Ben support desk — setup

Cloudflare Worker `ben-support-desk` receives inbound support mail from Postmark,
stores tickets in D1, drafts replies from playbooks, and posts to Slack for
human approval before sending.

**Distinct from `ben-email-in`:** separate worker name, webhook URL, `WEBHOOK_SECRET`,
and inbound address (`support-desk@in.benandbill.app`). Do not reuse the bills
worker secret or `/inbound` URL.

## Mail routing (already planned)

| Address | MX | Role |
|---------|-----|------|
| `@benandbill.app` (apex) | Google | `support@benandbill.app` inbox |
| `support-desk@in.benandbill.app` | Postmark (`in.benandbill.app`) | Forward target → webhook |

Gmail forwards a copy of mail to `support@benandbill.app` → `support-desk@in.benandbill.app`.

## Prerequisites

- Cloudflare account with Workers + D1 enabled
- `npx wrangler login` or `CLOUDFLARE_API_TOKEN` in the environment
- Postmark server with inbound domain `in.benandbill.app` (shared with bill email-in)
- Slack app with bot token, signing secret, and `#ben-support` channel

## 1. Create D1 database

```bash
cd backend/support-desk
npx wrangler d1 create ben-support-tickets
```

Copy the `database_id` from the output into `wrangler.toml` (replace the
`00000000-0000-0000-0000-000000000000` placeholder).

Apply schema:

```bash
npx wrangler d1 execute ben-support-tickets --file=schema.sql --remote
```

For local dev:

```bash
npx wrangler d1 execute ben-support-tickets --file=schema.sql --local
```

## 2. Set secrets

Generate a **new** webhook secret (do not reuse `ben-email-in`):

```bash
openssl rand -hex 32 | tee .webhook-secret.local
npx wrangler secret put WEBHOOK_SECRET   # paste value from .webhook-secret.local
```

Other secrets:

```bash
npx wrangler secret put SLACK_BOT_TOKEN
npx wrangler secret put SLACK_SIGNING_SECRET
npx wrangler secret put POSTMARK_SERVER_TOKEN
npx wrangler secret put SLACK_CHANNEL_ID
```

`SUPPORT_FROM_EMAIL` defaults to `support@benandbill.app` in `wrangler.toml`
`[vars]`. Override with a secret only if you need a different From address.

## 3. Deploy worker

```bash
cd backend/support-desk
npm test          # playbook unit tests
npx wrangler deploy
```

Note the workers.dev URL (e.g. `https://ben-support-desk.<account>.workers.dev`).

## 4. Postmark inbound webhook

In Postmark → your server → **Inbound** → **Webhook URL**:

```
https://<ben-support-desk-worker-url>/inbound?secret=<WEBHOOK_SECRET>
```

Use the support-desk secret from `.webhook-secret.local`, **not** the email-in secret.

Optional: configure a separate inbound stream or filter so support mail is
routed only to this webhook (bill mail continues to `ben-email-in`).

Confirm inbound address `support-desk@in.benandbill.app` is set up in Postmark
and Gmail forwarding delivers to it.

## 5. Slack app

See [SLACK.md](./SLACK.md) for the Slack app checklist (scopes, interactivity URL,
channel invite).

Interactivity request URL:

```
https://<ben-support-desk-worker-url>/slack/interactions
```

## 6. Smoke tests

Health:

```bash
curl -s "https://<worker-url>/health"
```

Inbound (replace secret and worker URL):

```bash
SECRET=$(cat .webhook-secret.local)
curl -s -X POST "https://<worker-url>/inbound?secret=${SECRET}" \
  -H "Content-Type: application/json" \
  -d '{
    "MessageID": "test-'$(date +%s)'",
    "ToFull": [{"Email": "support-desk@in.benandbill.app"}],
    "From": "Tester <tester@example.com>",
    "Subject": "How do I cancel my subscription?",
    "TextBody": "I want to cancel my trial please.",
    "Headers": [{"Name": "Message-ID", "Value": "<test@example.com>"}]
  }'
```

Expect `{"status":"ok","ticketId":"...","playbookId":"refund-trial"}` (or
`billing` depending on wording). A message should appear in `#ben-support`.

## Playbooks

Topic templates live in `docs/support-playbook/*.json`. Edit copy there, then
redeploy the worker (playbooks are bundled at build time). Run `npm test` after
keyword changes.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `401` on `/inbound` | `WEBHOOK_SECRET` matches query param |
| `unroutable` | `To` address includes `support-desk@in.benandbill.app` |
| No Slack message | `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`; bot invited to channel |
| Approve does not send | `POSTMARK_SERVER_TOKEN`; From address verified in Postmark |
| Slack buttons 401 | Interactivity URL + `SLACK_SIGNING_SECRET` |

If `wrangler` is not logged in on your machine, complete steps 1–2 when you have
API access; the repo ships with a placeholder `database_id` until then.
