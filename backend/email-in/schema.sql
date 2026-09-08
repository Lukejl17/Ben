-- Ben accounts: maps a verified Firebase user to their private email-in token.
-- The token is the unguessable part of bills-<token>@in.benandbill.app.
-- One row per user; the token is what R2 keys are prefixed with.

CREATE TABLE IF NOT EXISTS accounts (
  uid        TEXT PRIMARY KEY,          -- Firebase user id (stable across logins)
  token      TEXT NOT NULL UNIQUE,      -- random slug in the forwarding address
  email      TEXT,                      -- provider email, for display/support only
  provider   TEXT,                      -- apple | google | password
  created_at INTEGER NOT NULL           -- unix seconds
);

-- Fast lookup when inbound mail arrives addressed to a token.
CREATE INDEX IF NOT EXISTS idx_accounts_token ON accounts (token);
