# Ben email-in backend

One Cloudflare Worker + one R2 bucket. Postmark receives mail for
`bills-<token>@in.benandbill.app` and webhooks it here; attachments wait in
R2 until the app claims them through the confirm flow.

## Deploy (once Cloudflare account exists)
1. `cd backend/email-in && npx wrangler login` (or set CLOUDFLARE_API_TOKEN)
2. `npx wrangler r2 bucket create ben-inbound-bills`
3. `npx wrangler secret put WEBHOOK_SECRET`  (any long random string)
4. `npx wrangler deploy`  -> note the workers.dev URL

## Postmark config
- Server -> Inbound: set the webhook URL to
  `https://<worker-url>/inbound?secret=<WEBHOOK_SECRET>`
- Inbound domain: `in.benandbill.app` with the MX record Postmark shows
  (add it in Cloudflare DNS, priority 10).

## Not done yet (needs the account backend)
- Real auth on /pending and /blob (currently secret + unguessable token).
- The app-side fetch that pulls pending bills into the confirm flow.
