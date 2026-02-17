-- Add display_name column to users for friendly greetings
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;
-- Backfill existing rows to a sensible default (local part of email)
UPDATE users SET display_name = COALESCE(display_name, split_part(email, '@', 1));
