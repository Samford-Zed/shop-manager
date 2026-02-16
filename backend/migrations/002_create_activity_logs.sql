-- Migration: create activity_logs table to track product and sales events
CREATE TABLE IF NOT EXISTS activity_logs (
  id SERIAL PRIMARY KEY,
  actor_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  actor_role TEXT NOT NULL CHECK (actor_role IN ('OWNER','CASHIER')),
  action TEXT NOT NULL CHECK (action IN ('PRODUCT_ADD','PRODUCT_UPDATE','PRODUCT_DELETE','SALE_RECORD')),
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  details JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_actor_id ON activity_logs (actor_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_product_id ON activity_logs (product_id);

