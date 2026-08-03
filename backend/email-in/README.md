# Ben email-in backend

One Cloudflare Worker + one R2 bucket + one D1 database. Postmark receives mail
for `bills-<token>@in.benandbill.app` and webhooks it here; attachments wait in
R2 until the app claims them through the confirm flow.

## How auth works (plain version)

- Users log in with Firebase (Apple / Google / email+password). The app gets a
  short-lived proof-of-login token.
- The app sends that token to this Worker. The Worker checks it against Google's
  public keys (`src/firebase-auth.js`) — no passwords ever touch us.
- D1 (`ACCOUNTS`) maps each verified user id to a random email token. That token
  is the unguessable part of their `bills-<token>@in.benandbill.app` address.
- The Worker only ever lists / returns / deletes bills under the caller's own
  token. Postmark's inbound webhook stays on the shared `WEBHOOK_SECRET`.

## Attachment filtering

On `/inbound`, we only store bill-like attachments:

- If the mail has any **PDF**, only PDFs are kept (signature PNGs/JPEGs are ignored).
- Otherwise images are kept only when they look like a real scan: no inline
  `ContentID` (Postmark marks signature/logo embeds this way), not tiny
  (&lt;40KB), and not named like `signature` / `logo` / social icons.

## Endpoints

| Route | Auth | Purpose |
|-------|------|---------|
| `POST /inbound?secret=…` | `WEBHOOK_SECRET` | Postmark webhook → store attachments in R2 |
| `POST /register` | Bearer Firebase token | mint/return the user's forwarding address |
| `GET /pending` | Bearer Firebase token | list the user's waiting bills |
| `GET /blob?key=…` | Bearer Firebase token | download one waiting bill (ownership checked) |
| `POST /claim` `{key}` | Bearer Firebase token | delete a bill after the app confirms it |

Authenticated routes return `503 auth not configured` until the
`FIREBASE_PROJECT_ID` secret is set (see below).

## Deploy status (19 Jul 2026)

| Step | Status |
|------|--------|
| R2 bucket `ben-inbound-bills` | Done |
| `WEBHOOK_SECRET` on worker | Done (local copy: `.webhook-secret.local`, gitignored) |
| Worker deploy | Done — `https://ben-email-in.luke-9e7.workers.dev` |
| MX `in.benandbill.app` → `inbound.postmarkapp.com` | Added in Cloudflare DNS |
| Nameservers on `benandbill.app` | **Pending** — still Squarespace; switch to Cloudflare for MX to go live |
| Postmark inbound domain + webhook | **You** — see below |

**Webhook URL** (paste into Postmark → Server → Inbound → Webhook):

```
https://ben-email-in.luke-9e7.workers.dev/inbound?secret=<WEBHOOK_SECRET>
```

Use the value from `.webhook-secret.local` (never commit it).

**Nameserver switch** (Squarespace → Cloudflare, one-time):

- `kimora.ns.cloudflare.com`
- `zahir.ns.cloudflare.com`

Until that propagates, mail to `@in.benandbill.app` will not reach Postmark. You can still
verify the pipe with Postmark's **Send test** webhook (bypasses MX).

## Deploy (once Cloudflare account exists)
1. `cd backend/email-in && npx wrangler login` (or set CLOUDFLARE_API_TOKEN)
2. `npx wrangler r2 bucket create ben-inbound-bills`
3. `npx wrangler d1 create ben-accounts` (paste the id into `wrangler.toml`)
4. `npx wrangler d1 execute ben-accounts --file=schema.sql --remote`
5. `npx wrangler secret put WEBHOOK_SECRET`  (any long random string; save to `.webhook-secret.local`)
6. `npx wrangler secret put FIREBASE_PROJECT_ID`  (from your Firebase project settings)
7. `npx wrangler deploy`  -> note the workers.dev URL

## Postmark config
- Server -> Inbound: set the webhook URL to
  `https://<worker-url>/inbound?secret=<WEBHOOK_SECRET>`
- Inbound domain: `in.benandbill.app` with the MX record Postmark shows
  (add it in Cloudflare DNS, priority 10 → `inbound.postmarkapp.com`).

Postmark UI checklist:
1. Open your inbound **message stream** → **Settings**.
2. Set **Inbound webhook URL** to the URL above.
3. Under **Inbound domain forwarding**, add `in.benandbill.app` and verify MX
   (will show green once Cloudflare nameservers are live).
4. Use **Send test** to confirm the worker returns `ok`.

## Smoke test (after deploy)

```bash
cd backend/email-in
SECRET=$(cat .webhook-secret.local)
curl -s -X POST "https://ben-email-in.luke-9e7.workers.dev/inbound?secret=${SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"ToFull":[{"Email":"bills-testtoken@in.benandbill.app"}],"From":"test@example.com","Subject":"test","Attachments":[]}'
# expect: ok
```

## Not done yet (needs the account backend)
- Real auth on /pending and /blob (currently secret + unguessable token).
- The app-side fetch that pulls pending bills into the confirm flow.
