# Ben support desk setup

Cloudflare Worker that receives support mail from Postmark, drafts a reply from
playbooks, posts it to Slack for human approval, and sends approved replies via
Postmark outbound from `support@benandbill.app`.

This is separate from [ben-email-in](../email-in/README.md) (bill attachments).

## Architecture

```
support@benandbill.app (Postmark inbound)
        │
        ▼
POST /inbound?secret=…  →  match playbook  →  D1 ticket (pending)
        │
        ├─ Slack #ben-support (Approve / Reject / Send to Engineer)
        │     ├─ Approve → Postmark outbound API → customer
        │     └─ Reject  → ticket status dismissed
        │
        └─ bug-report playbook (or Send to Engineer)
              ▼
         #ben-engineering-support-tickets  (ENGINEER_HANDOFF)
```

## Prerequisites

- Cloudflare account with Workers + D1 enabled
- Postmark server with inbound address for support mail and outbound stream
- Slack app with bot token and interactive components URL

## Deploy

```bash
cd backend/support-desk
npx wrangler login   # or set CLOUDFLARE_API_TOKEN
```

1. **Create D1 database**

   ```bash
   npx wrangler d1 create ben-support-tickets
   ```

   Paste the returned `database_id` into `wrangler.toml` (replace the placeholder).

2. **Apply schema**

   ```bash
   npx wrangler d1 execute ben-support-tickets --file=schema.sql --remote
   ```

   If the D1 database already existed before Engineer handoff:

   ```bash
   npx wrangler d1 execute ben-support-tickets --file=schema-engineer.sql --remote
   ```

3. **Sync playbooks** (bundled into the worker at deploy time)

   ```bash
   node scripts/sync-playbooks.js
   ```

   Re-run after editing `docs/support-playbook/*.json`.

4. **Set secrets** (never commit values; use `*.local` files locally)

   ```bash
   npx wrangler secret put WEBHOOK_SECRET
   npx wrangler secret put SLACK_BOT_TOKEN
   npx wrangler secret put SLACK_SIGNING_SECRET
   npx wrangler secret put POSTMARK_SERVER_TOKEN
   npx wrangler secret put SLACK_CHANNEL_ID
   ```

   `SUPPORT_FROM_EMAIL` defaults to `support@benandbill.app` in `wrangler.toml` `[vars]`.
   `ENGINEER_CHANNEL_ID` defaults to `#ben-engineering-support-tickets` (`C0C0CAR1P9S`).
   Invite the **Ben Support** Slack bot to that channel or Engineer handoff posts will fail.

5. **Deploy**

   ```bash
   npx wrangler deploy
   ```

   Note the workers.dev URL (e.g. `https://ben-support-desk.<account>.workers.dev`).

## Postmark inbound

1. Add inbound address `support@benandbill.app` (or forward support mail there).
2. Set the inbound webhook URL:

   ```
   https://<worker-url>/inbound?secret=<WEBHOOK_SECRET>
   ```

3. Use Postmark **Send test** to confirm the worker returns `{ "status": "ok" }`.

Save `WEBHOOK_SECRET` locally as `.webhook-secret.local` (gitignored).

## Endpoints

| Route | Auth | Purpose |
|-------|------|---------|
| `GET /health` | none | Liveness check |
| `POST /inbound?secret=…` | `WEBHOOK_SECRET` query param | Postmark inbound → playbook draft → D1 + Slack |
| `POST /slack/interactions` | Slack signing secret | Approve / Reject / Send to Engineer |

## Local testing

### Unit tests (playbook matching)

```bash
cd backend/support-desk
npm test
```

### Wrangler dev (needs remote D1 or local sqlite)

```bash
cd backend/support-desk
npx wrangler dev
```

Post a sample inbound payload:

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

Slack interactions require a real Slack request signature; test Approve/Reject in a
deployed worker with the Slack app configured (see [SLACK.md](./SLACK.md)).

## Secrets checklist

| Name | Where | Purpose |
|------|-------|---------|
| `WEBHOOK_SECRET` | wrangler secret | Postmark `/inbound?secret=` |
| `SLACK_BOT_TOKEN` | wrangler secret | `chat.postMessage` / `chat.update` |
| `SLACK_SIGNING_SECRET` | wrangler secret | Verify `/slack/interactions` |
| `POSTMARK_SERVER_TOKEN` | wrangler secret | Outbound replies |
| `SLACK_CHANNEL_ID` | wrangler secret | Target channel (e.g. `#ben-support`) |
| `SUPPORT_FROM_EMAIL` | wrangler `[vars]` | Default `support@benandbill.app` |

## Playbooks

Canonical JSON lives in `docs/support-playbook/`. The worker bundles copies from
`src/playbooks/` — run `node scripts/sync-playbooks.js` after edits, then redeploy.

## D1 ticket statuses

| Status | Meaning |
|--------|---------|
| `pending` | Awaiting Slack Approve/Reject |
| `sent` | Approved and emailed via Postmark |
| `dismissed` | Rejected in Slack |
| `pending_edit` | Reserved for future edit-before-send flow |
