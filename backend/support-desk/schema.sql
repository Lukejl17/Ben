-- Ben support desk — tickets + living playbook (D1)
CREATE TABLE IF NOT EXISTS tickets (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  status TEXT NOT NULL, -- pending_approval | sent | rejected | closed
  customer_email TEXT NOT NULL,
  customer_name TEXT,
  subject TEXT NOT NULL,
  body_plain TEXT NOT NULL,
  body_snippet TEXT NOT NULL,
  topic TEXT,
  draft_reply TEXT NOT NULL,
  playbook_id TEXT,
  slack_ts TEXT,
  slack_channel TEXT,
  postmark_message_id TEXT,
  outbound_message_id TEXT
);

CREATE TABLE IF NOT EXISTS playbook_entries (
  id TEXT PRIMARY KEY,
  topic TEXT NOT NULL,
  tags TEXT NOT NULL, -- comma-separated
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  hit_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  source TEXT NOT NULL -- seed | approved
);

CREATE TABLE IF NOT EXISTS ticket_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ticket_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  kind TEXT NOT NULL,
  detail TEXT
);

CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_playbook_topic ON playbook_entries(topic);
