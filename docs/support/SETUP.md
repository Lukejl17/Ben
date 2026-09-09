# Ben support desk setup

Cloudflare Worker that receives support mail from Postmark, drafts a reply from
playbooks, posts it to Slack for human approval, and sends approved replies via
Postmark outbound from `support@benandbill.app`.

This is a **separate** worker from bills inbound (`ben-email-in`). Do not reuse
that worker, its D1 database, its webhook secret, or its Postmark inbound URL.

## What this repo ships

The worker code, playbooks, D1 schema, and Slack/Postmark docs. Merging this
does **not** make mail arrive in `#ben-support` by itself. Cloudflare, Postmark,
and Slack still need dashboard clicks (logins are not in git).

```
support@benandbill.app (Postmark inbound)
        |
        v
POST /inbound?secret=…  →  match playbook  →  D1 ticket (pending)
        |
        |- Slack #ben-support (Approve / Reject / Send to Engineer)
        |     |- Approve → Postmark outbound API → customer
        |     +- Reject  → ticket status dismissed
        |
        +- bug-report playbook (or Send to Engineer)
              v
         #ben-engineering-support-tickets  (ENGINEER_HANDOFF)
```

## What still needs a login (plain English)

Do these in the websites, not in Terminal. Leave the bills mail pipe alone.

1. **Cloudflare** → Workers & Pages → D1 → create a database named
   `ben-support-tickets`. Copy the database ID. It replaces the zeros in
   `backend/support-desk/wrangler.toml`.
2. **Cloudflare** → Workers → create/deploy worker `ben-support-desk` from this
   folder (or run `npm run go-live` on a machine already logged into Wrangler).
3. **Cloudflare** → that worker → Settings → Variables and secrets. Add
   (never paste these into git or Slack):
   - `WEBHOOK_SECRET` (a long random string you also put on the Postmark URL)
   - `SLACK_BOT_TOKEN` (Ben Support Slack app, starts with `xoxb-`)
   - `SLACK_SIGNING_SECRET` (same Slack app → Basic Information)
   - `POSTMARK_SERVER_TOKEN` (Postmark **Ben Support Desk** server token)
4. **Postmark** → add a **new** server named Ben Support Desk. Set its inbound
   webhook to `https://<worker-url>/inbound?secret=<WEBHOOK_SECRET>`.
   Do **not** change the existing bills server webhook.
5. Forward `support@benandbill.app` to that Postmark inbound address (the hash
   `@inbound.postmarkapp.com` address on the new server).
6. **Slack** → invite `@Ben Support` to `#ben-support` and to
   `#ben-engineering-support-tickets`. Turn on Interactivity and set the
   Request URL to `https://<worker-url>/slack/interactions`.

`SLACK_CHANNEL_ID` (`#ben-support`, `C0BV6LP1X8F`) and `ENGINEER_CHANNEL_ID`
(`C0C0CAR1P9S`) are already in `wrangler.toml`. `SUPPORT_FROM_EMAIL` is already
`support@benandbill.app`.

Until steps 1-6 are done, `GET /health` on the documented workers.dev URL can
fail (Cloudflare 1042 = worker not deployed), and `#ben-support` will have no
ticket cards.

## Engineer go-live (logged-in Wrangler only)

Does not print or commit secrets. Does not touch `ben-email-in`.

```bash
cd backend/support-desk
npm test
npm run go-live
```

That script: checks Wrangler login, creates D1 if needed, writes `database_id`
into `wrangler.toml`, applies `schema.sql`, deploys. If Wrangler is not logged
in it exits and leaves the dashboard list above.

If the D1 database already existed before Engineer handoff columns:

```bash
npx wrangler d1 execute ben-support-tickets --file=schema-engineer.sql --remote
```

Sync playbooks into the worker bundle after editing `docs/support-playbook/*.json`:

```bash
node scripts/sync-playbooks.js
```

## Endpoints

| Route | Auth | Purpose |
|-------|------|---------|
| `GET /health` | none | Liveness check |
| `POST /inbound?secret=…` | `WEBHOOK_SECRET` query param | Postmark inbound → playbook draft → D1 + Slack |
| `POST /slack/interactions` | Slack signing secret | Approve / Reject / Send to Engineer |

## Local testing

```bash
cd backend/support-desk
npm test
```

Pure playbook matching, Slack HMAC, inbound/Slack interaction behaviour with a
fake D1. Slack signature checks and Postmark sends need a deployed worker for
a live click-through (see [SLACK.md](./SLACK.md) and [POSTMARK.md](./POSTMARK.md)).

### Wrangler dev (needs D1)

```bash
cd backend/support-desk
npx wrangler dev
```

Post a sample inbound payload (secret from a gitignored local file):

```bash
SECRET=$(cat .webhook-secret.local)
curl -s -X POST "http://localhost:8787/inbound?secret=${SECRET}" \
  -H "Content-Type: application/json" \
  -d '{
    "MessageID": "test-'$(date +%s)'",
    "From": "Customer <customer@example.com>",
    "FromFull": { "Email": "customer@example.com", "Name": "Customer" },
    "Subject": "Refund request",
    "TextBody": "I would like a refund for my trial subscription.",
    "Headers": [{ "Name": "Message-ID", "Value": "<cust-msg@example.com>" }]
  }'
```

Expect: `{"status":"ok","ticket_id":"...","playbook_id":"refund-trial"}`

## Secrets checklist

| Name | Where | Purpose |
|------|-------|---------|
| `WEBHOOK_SECRET` | wrangler secret | Postmark `/inbound?secret=` |
| `SLACK_BOT_TOKEN` | wrangler secret | `chat.postMessage` / `chat.update` |
| `SLACK_SIGNING_SECRET` | wrangler secret | Verify `/slack/interactions` |
| `POSTMARK_SERVER_TOKEN` | wrangler secret | Outbound replies |
| `SLACK_CHANNEL_ID` | wrangler `[vars]` | `#ben-support` (`C0BV6LP1X8F`) |
| `ENGINEER_CHANNEL_ID` | wrangler `[vars]` | `#ben-engineering-support-tickets` |
| `SUPPORT_FROM_EMAIL` | wrangler `[vars]` | Default `support@benandbill.app` |

## Playbooks

Canonical JSON lives in `docs/support-playbook/`. The worker bundles copies from
`src/playbooks/`. Run `node scripts/sync-playbooks.js` after edits, then redeploy.

## D1 ticket statuses

| Status | Meaning |
|--------|---------|
| `pending` | Awaiting Slack Approve/Reject |
| `sent` | Approved and emailed via Postmark |
| `dismissed` | Rejected in Slack |
| `pending_edit` | Reserved for future edit-before-send flow |
