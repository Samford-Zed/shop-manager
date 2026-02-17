-- Add 'name' column to users (only this word)
ALTER TABLE users ADD COLUMN IF NOT EXISTS name TEXT;

-- Backfill: if name is NULL or empty, use local part of email (before @)
UPDATE users
SET name = COALESCE(NULLIF(name, ''), split_part(email, '@', 1));

-- Optional: enforce NOT NULL after backfill (commented out)
-- ALTER TABLE users ALTER COLUMN name SET NOT NULL;
