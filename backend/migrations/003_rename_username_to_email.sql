-- Rename users.username to users.email
ALTER TABLE users RENAME COLUMN username TO email;

-- If there are any indexes or constraints named with 'username', consider renaming them here.
-- Example for a unique index:
-- ALTER INDEX IF EXISTS users_username_key RENAME TO users_email_key;

