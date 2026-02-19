const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

const pool = require('./db');

async function ensureActivityLogs() {
  const sql = `
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
  `;
  try {
    await pool.query(sql);
    console.log('✅ activity_logs ensured');
  } catch (e) {
    console.error('Failed to ensure activity_logs:', e.message);
  }
}

const app = express();
app.use(cors());
app.use(express.json());

// Ensure table exists at startup
ensureActivityLogs();

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';

// Preflight: ensure DB configuration present via db.js
if (!process.env.DATABASE_URL && !(process.env.PGUSER && process.env.PGHOST && process.env.PGDATABASE && process.env.PGPASSWORD && process.env.PGPORT)) {
  console.warn('Warning: DATABASE_URL or full PG env vars not set. db.js will throw on startup if missing.');
}

if (!process.env.JWT_SECRET) {
  throw new Error("JWT_SECRET is not defined in environment variables");
}
const JWT_SECRET = process.env.JWT_SECRET;

/* ================= AUTH ================= */

const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ message: 'No token provided' });

  const token = authHeader.split(' ')[1];
  try {
    req.user = jwt.verify(token, JWT_SECRET); // {id, email, role}
    next();
  } catch {
    res.status(401).json({ message: 'Invalid token' });
  }
};

const ownerOnly = (req, res, next) => {
  if (req.user.role !== 'OWNER')
    return res.status(403).json({ message: 'OWNER only' });
  next();
};

// Allow OWNER or CASHIER
const ownerOrCashier = (req, res, next) => {
  if (req.user.role !== 'OWNER' && req.user.role !== 'CASHIER') {
    return res.status(403).json({ message: 'OWNER or CASHIER only' });
  }
  next();
};

/* ================= AUTH ROUTES ================= */

app.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;
    if (!email || !password)
      return res.status(400).json({ message: 'email and password required' });

    const exists = await pool.query('SELECT id FROM users WHERE email=$1', [email]);
    if (exists.rows.length) return res.status(400).json({ message: 'Email exists' });

    const friendly = (name || '').trim() || email.split('@')[0];
    const hashed = await bcrypt.hash(password, 10);
    await pool.query(
      "INSERT INTO users (email, password, role, name) VALUES ($1,$2,'OWNER',$3)",
      [email, hashed, friendly]
    );
    res.status(201).json({ message: 'Owner registered' });
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    // Select a friendly_name coalesced from name or email local part
    const result = await pool.query(
      `SELECT id, email, password, role, COALESCE(name, split_part(email,'@',1)) AS friendly_name
       FROM users WHERE email=$1`,
      [email]
    );
    if (!result.rows.length) return res.status(400).json({ message: 'User not found' });
    const user = result.rows[0];
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(400).json({ message: 'Invalid password' });

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role, name: user.friendly_name },
      JWT_SECRET,
      { expiresIn: '1h' }
    );

    res.json({ token, role: user.role, name: user.friendly_name });
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ================= PRODUCTS ================= */

// GET products (OWNER + CASHIER)
app.get('/products', authMiddleware, async (_, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, price::numeric, stock_quantity
       FROM products
       ORDER BY created_at DESC`
    );
    res.json(result.rows);
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// ADD product (OWNER)
app.post('/products', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const { name, price, stock_quantity } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `INSERT INTO products (name, price, stock_quantity)
         VALUES ($1,$2,$3)
         RETURNING id, name, price::numeric, stock_quantity`,
        [name, price, stock_quantity]
      );
      const product = result.rows[0];
      await client.query(
        `INSERT INTO activity_logs (actor_id, actor_role, action, product_id, details)
         VALUES ($1,$2,$3,$4,$5)`,
        [req.user.id, req.user.role, 'PRODUCT_ADD', product.id, JSON.stringify({ name, price, stock_quantity })]
      );
      await client.query('COMMIT');
      res.status(201).json(product);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// UPDATE product (OWNER)
app.put('/products/:id', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, price, stock_quantity } = req.body;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `UPDATE products
         SET name=$1, price=$2, stock_quantity=$3, updated_at=NOW()
         WHERE id=$4
         RETURNING id, name, price::numeric, stock_quantity`,
        [name, price, stock_quantity, id]
      );
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Not found' });
      }
      const product = result.rows[0];
      await client.query(
        `INSERT INTO activity_logs (actor_id, actor_role, action, product_id, details)
         VALUES ($1,$2,$3,$4,$5)`,
        [req.user.id, req.user.role, 'PRODUCT_UPDATE', product.id, JSON.stringify({ name, price, stock_quantity })]
      );
      await client.query('COMMIT');
      res.json(product);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// DELETE product (OWNER)
app.delete('/products/:id', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const id = req.params.id;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Check if there are sales referencing this product (FK RESTRICT in sales)
      const salesRef = await client.query('SELECT 1 FROM sales WHERE product_id=$1 LIMIT 1', [id]);
      if (salesRef.rows.length) {
        await client.query('ROLLBACK');
        return res.status(409).json({ message: 'Cannot delete product: existing sales reference this product' });
      }

      const before = await client.query('SELECT id, name FROM products WHERE id=$1', [id]);
      if (!before.rows.length) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Not found' });
      }
      const prod = before.rows[0];

      // Log activity BEFORE deleting so FK is satisfied
      await client.query(
        `INSERT INTO activity_logs (actor_id, actor_role, action, product_id, details)
         VALUES ($1,$2,$3,$4,$5)`,
        [req.user.id, req.user.role, 'PRODUCT_DELETE', prod.id, JSON.stringify({ name: prod.name })]
      );

      // Now delete the product
      const del = await client.query('DELETE FROM products WHERE id=$1', [id]);
      if (!del.rowCount) {
        await client.query('ROLLBACK');
        return res.status(404).json({ message: 'Not found' });
      }
      await client.query('COMMIT');
      res.json({ message: 'Deleted' });
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('DELETE /products error:', e.message);
      return res.status(500).json({ message: 'Server error', error: e.message });
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ================= SALES (CASHIER) ================= */
app.post('/sales', authMiddleware, ownerOrCashier, async (req, res) => {
  try {
    const { product_id, quantity } = req.body;
    const qty = parseInt(quantity, 10);
    if (!product_id || !qty || qty <= 0) {
      return res.status(400).json({ message: 'product_id and positive quantity required' });
    }

    // Check product and stock
    const prodRes = await pool.query(
      'SELECT id, name, price::numeric, stock_quantity FROM products WHERE id=$1',
      [product_id]
    );
    if (!prodRes.rows.length) {
      return res.status(404).json({ message: 'Product not found' });
    }
    const product = prodRes.rows[0];
    if (product.stock_quantity < qty) {
      return res.status(400).json({ message: 'Insufficient stock' });
    }

    // Transaction: decrement stock and record sale
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const unitPrice = parseFloat(product.price);
      const totalPrice = unitPrice * qty;

      await client.query(
        `UPDATE products
         SET stock_quantity = stock_quantity - $1, updated_at = NOW()
         WHERE id = $2`,
        [qty, product_id]
      );

      await client.query(
        `INSERT INTO sales (product_id, cashier_id, quantity, unit_price, total_price)
         VALUES ($1,$2,$3,$4,$5)`,
        [product_id, req.user.id, qty, unitPrice, totalPrice]
      );

      // NEW: log activity
      await client.query(
        `INSERT INTO activity_logs (actor_id, actor_role, action, product_id, details)
         VALUES ($1,$2,$3,$4,$5)`,
        [req.user.id, req.user.role, 'SALE_RECORD', product_id, JSON.stringify({ quantity: qty, unitPrice, totalPrice })]
      );
      await client.query('COMMIT');
    } catch (txErr) {
      await client.query('ROLLBACK');
      throw txErr;
    } finally {
      client.release();
    }

    return res.status(201).json({ message: 'Sale recorded' });
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ================= SALES LIST (OWNER or CASHIER) ================= */
app.get('/sales', authMiddleware, ownerOrCashier, async (req, res) => {
  try {
    const { from, to } = req.query;
    const role = req.user.role;
    const params = [];
    let where = 'WHERE 1=1';
    if (role === 'CASHIER') {
      params.push(req.user.id);
      where += ` AND s.cashier_id = $${params.length}`;
    }
    if (from) {
      params.push(from);
      where += ` AND s.created_at >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      where += ` AND s.created_at <= $${params.length}`;
    }

    const sql = `
      SELECT s.id,
             s.product_id,
             COALESCE(p.name,'') AS product_name,
             s.cashier_id,
             COALESCE(u.email,'') AS cashier_email,
             COALESCE(u.name, split_part(u.email,'@',1)) AS cashier_name,
             s.quantity,
             s.unit_price::numeric AS unit_price,
             s.total_price::numeric AS total_price,
             s.created_at
      FROM sales s
      LEFT JOIN products p ON p.id = s.product_id
      LEFT JOIN users u ON u.id = s.cashier_id
      ${where}
      ORDER BY s.created_at DESC
      LIMIT 500`;

    const result = await pool.query(sql, params);
    res.json(result.rows);
  } catch (e) {
    console.error('GET /sales error:', e.message);
    res.status(200).json([]);
  }
});

/* ================= REPORTS (OWNER) ================= */
app.get('/reports/summary', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const { period } = req.query;
    if (period) {
      const allowed = { week: 'week', month: 'month', year: 'year' };
      const trunc = allowed[String(period).toLowerCase()];
      if (!trunc) return res.status(400).json({ message: 'Invalid period' });

      const result = await pool.query(
        `SELECT
           COALESCE(SUM(total_price),0) AS revenue,
           COALESCE(SUM(quantity),0) AS items
         FROM sales
         WHERE created_at >= date_trunc('${trunc}', NOW())`
      );
      return res.json({
        revenue: parseFloat(result.rows[0].revenue || 0),
        items: parseInt(result.rows[0].items || 0, 10),
      });
    }

    const { from, to } = req.query;
    // Default range: last 30 days
    const result = await pool.query(
      `SELECT
         COALESCE(SUM(total_price),0) AS revenue,
         COUNT(*) AS orders,
         COALESCE(SUM(quantity),0) AS items
       FROM sales`,
    );
    const productsCount = await pool.query('SELECT COUNT(*) AS cnt FROM products');
    const cashiersCount = await pool.query("SELECT COUNT(*) AS cnt FROM users WHERE role='CASHIER'");

    res.json({
      totalProducts: parseInt(productsCount.rows[0].cnt, 10),
      totalCashiers: parseInt(cashiersCount.rows[0].cnt, 10),
      revenue: parseFloat(result.rows[0].revenue || 0),
      orders: parseInt(result.rows[0].orders || 0, 10),
      items: parseInt(result.rows[0].items || 0, 10),
    });
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

app.get('/reports/heatmap', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const days = parseInt(req.query.days || '90', 10);
    // Aggregate sales count per day for last N days
    const result = await pool.query(
      `SELECT
         DATE_TRUNC('day', created_at) AS day,
         COUNT(*) AS count,
         COALESCE(SUM(total_price),0) AS revenue
       FROM sales
       WHERE created_at >= NOW() - INTERVAL '${days} days'
       GROUP BY 1
       ORDER BY 1`
    );
    // Return as [{date: 'YYYY-MM-DD', count, revenue}]
    const data = result.rows.map(r => ({
      date: new Date(r.day).toISOString().slice(0,10),
      count: parseInt(r.count, 10),
      revenue: parseFloat(r.revenue || 0),
    }));
    res.json(data);
  } catch (e) {
    console.error(e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ================= CASHIER MANAGEMENT (OWNER) ================= */
app.get('/cashiers', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, name, role, created_at
       FROM users
       WHERE role = 'CASHIER'
       ORDER BY created_at DESC`
    );
    res.json(result.rows);
  } catch (e) {
    console.error('GET /cashiers error:', e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// Create cashier account (OWNER)
app.post('/cashiers', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const { email, password, name } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'email and password required' });
    }
    const exists = await pool.query('SELECT id FROM users WHERE email=$1', [email]);
    if (exists.rows.length) return res.status(400).json({ message: 'Email exists' });
    const friendly = (name || '').trim() || email.split('@')[0];
    const hashed = await bcrypt.hash(password, 10);
    await pool.query(
      `INSERT INTO users (email, password, role, name)
       VALUES ($1,$2,'CASHIER',$3)`,
      [email, hashed, friendly]
    );
    return res.status(201).json({ message: 'Cashier created' });
  } catch (e) {
    console.error('POST /cashiers error:', e.message);
    res.status(500).json({ message: 'Server error' });
  }
});

/* ================= ACTIVITY (OWNER) ================= */
app.get('/activity', authMiddleware, ownerOnly, async (req, res) => {
  try {
    const { limit } = req.query;
    const n = Math.min(parseInt(limit || '200', 10), 500);
    const result = await pool.query(
      `SELECT a.id, a.actor_id,
              u.email AS actor_email,
              COALESCE(u.name, split_part(u.email,'@',1)) AS actor_name,
              a.actor_role, a.action, a.product_id,
              p.name AS product_name, a.details, a.created_at
       FROM activity_logs a
       LEFT JOIN users u ON u.id = a.actor_id
       LEFT JOIN products p ON p.id = a.product_id
       ORDER BY a.created_at DESC
       LIMIT $1`,
      [n]
    );
    res.json(result.rows);
  } catch (e) {
    console.error('GET /activity error:', e.message);
    res.status(200).json([]);
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, HOST, () =>
  console.log(`🚀 Shop server running on http://${HOST}:${PORT}`)
);
