# Ben support desk — Slack setup

Human checklist for wiring Slack to `ben-support-desk`.

## Create the Slack app

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**.
2. Name: `Ben Support` (or similar). Workspace: your team.

## Bot token scopes

**OAuth & Permissions** → **Bot Token Scopes**:

| Scope | Why |
|-------|-----|
| `chat:write` | Post ticket messages to `#ben-support` |
| `chat:write.public` | Post if the bot is not yet in the channel (optional but handy) |

Install the app to the workspace and copy the **Bot User OAuth Token** (`xoxb-...`).

```bash
cd backend/support-desk
npx wrangler secret put SLACK_BOT_TOKEN
```

## Signing secret

**Basic Information** → **App Credentials** → **Signing Secret**:

```bash
npx wrangler secret put SLACK_SIGNING_SECRET
```

Required for `POST /slack/interactions` verification.

## Interactivity

**Interactivity & Shortcuts** → turn **Interactivity** on.

**Request URL** (after deploy):

```
https://<ben-support-desk-worker-url>/slack/interactions
```

No slash command needed for v1; buttons on ticket messages are enough.

## Channel

1. Create `#ben-support` (private recommended).
2. Invite the Ben Support bot: `/invite @Ben Support`.
3. Copy the channel ID (right-click channel → **View channel details** → bottom of modal, or from the URL `.../archives/C0123ABCDEF`).

```bash
npx wrangler secret put SLACK_CHANNEL_ID
```

## Button behaviour

Each inbound email creates a Slack message with:

| Button | Action |
|--------|--------|
| **Approve** | Sends the draft reply via Postmark to the customer; ticket → `sent` |
| **Reject** | Marks ticket `dismissed`; no email sent |
| **Edit** | Marks `pending_edit`; edit the draft manually (D1 or future UI), then send or re-post |

Messages update in place after a button click (buttons removed once handled).

## Security notes

- Never commit `xoxb-` tokens or signing secrets.
- Restrict `#ben-support` to people who may approve customer email.
- Rotate tokens if leaked; update wrangler secrets and redeploy.

## Verify

1. Trigger a test inbound (see [SETUP.md](./SETUP.md) smoke test).
2. Confirm the ticket appears in `#ben-support` with playbook name and draft body.
3. Click **Reject** on a test ticket first; confirm the message updates to `dismissed`.
4. Send another test; click **Approve** and confirm the reply arrives from
   `support@benandbill.app`.
