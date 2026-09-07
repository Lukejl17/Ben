# Slack — Ben Support Desk (do this while Workspace is cooking)

Goal: a private `#ben-support` channel + a Slack app that can post drafts and receive button clicks. Takes ~8 minutes.

## A. Channel (2 min)

1. In your Ben / Repertoire Slack workspace, create a **private** channel: `#ben-support`.
2. Open channel details → copy the **Channel ID** (starts with `C`).
   - Tip: Slack → Preferences → Advanced → “Show developer tools” / channel ID in the URL after `/archives/`.

Paste here when ready:

```
SLACK_CHANNEL_ID=C…
```

## B. Slack app (5 min)

1. Open https://api.slack.com/apps → **Create New App** → **From scratch**
2. Name: `Ben Support Desk`
3. Pick the workspace you’ll use for ops → Create

### OAuth & Permissions → Bot Token Scopes

Add:

- `chat:write`
- `channels:history` (public channels; harmless if unused)
- `groups:history` (required for **private** `#ben-support` + `edit:` thread replies)
- `reactions:write`

Then **Install to Workspace** → Allow.

Copy:

```
SLACK_BOT_TOKEN=xoxb-…
```

### Basic Information → App Credentials

Copy:

```
SLACK_SIGNING_SECRET=…
```

### Invite the bot

In `#ben-support`: `/invite @Ben Support Desk`

### Interactivity (leave blank until Worker is live)

We’ll fill this after deploy:

```
https://ben-support-desk.<subdomain>.workers.dev/slack/interactions
```

Enable Interactivity → paste that URL → Save.

## C. Hand-off checklist

When A+B are done, paste the three values (token, signing secret, channel ID) into this chat or drop them in a local gitignored file, e.g.:

`backend/support-desk/.secrets.local` (never commit)

Then say **“Slack ready”** and I’ll put secrets on the Worker and finish deploy.
