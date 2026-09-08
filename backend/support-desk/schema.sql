-- Ben support desk: inbound support emails awaiting human approval in Slack.
-- One row per Postmark inbound message. Draft replies come from playbooks;
-- Approve in Slack sends via Postmark outbound.

CREATE TABLE IF NOT EXISTS tickets (
  id                  TEXT PRIMARY KEY,           -- random id (also in Slack button value)
  postmark_message_id TEXT NOT NULL UNIQUE,       -- Postmark MessageID for dedup
  from_email          TEXT NOT NULL,
  from_name           TEXT,
  subject             TEXT NOT NULL,
  body_text           TEXT,
  body_html           TEXT,
  message_id_header   TEXT,                       -- RFC Message-ID for threading replies
  playbook_id         TEXT NOT NULL,              -- matched playbook slug
  draft_subject       TEXT NOT NULL,
  draft_body          TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'pending',
  -- pending | approved | sent | dismissed | pending_edit
  slack_channel       TEXT,
  slack_message_ts    TEXT,
  created_at          INTEGER NOT NULL,
  updated_at          INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets (status);
CREATE INDEX IF NOT EXISTS idx_tickets_created ON tickets (created_at);
