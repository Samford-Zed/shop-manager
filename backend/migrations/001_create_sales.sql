-- Migration: create sales table
-- Minimal schema to support summary and heatmap endpoints

CREATE TABLE IF NOT EXISTS sales (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  cashier_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  total_price NUMERIC(12,2) NOT NULL CHECK (total_price >= 0),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Helpful indexes for reporting
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales (created_at);
CREATE INDEX IF NOT EXISTS idx_sales_cashier_id ON sales (cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_product_id ON sales (product_id);

