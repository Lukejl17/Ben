-- Existing D1 databases created before Engineer handoff: add columns once.
-- New installs get these from schema.sql CREATE TABLE.

ALTER TABLE tickets ADD COLUMN engineer_channel TEXT;
ALTER TABLE tickets ADD COLUMN engineer_message_ts TEXT;
