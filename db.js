// db.js
require('dotenv').config();
const { Pool } = require('pg');

// Prefer DATABASE_URL; otherwise use discrete env vars. Do not hardcode secrets.
let pool;
if (process.env.DATABASE_URL) {
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });
} else {
  const user = process.env.PGUSER;
  const host = process.env.PGHOST;
  const database = process.env.PGDATABASE;
  const password = process.env.PGPASSWORD;
  const port = process.env.PGPORT ? parseInt(process.env.PGPORT, 10) : undefined;

  if (!user || !host || !database || !password || !port) {
    throw new Error('DATABASE_URL or full PG env vars (PGUSER, PGHOST, PGDATABASE, PGPASSWORD, PGPORT) must be defined');
  }
  pool = new Pool({ user, host, database, password, port });
}

// Test connection (safe for startup)
pool.connect()
  .then(client => {
    console.log('Connected to PostgreSQL successfully!');
    client.release();
  })
  .catch(err => console.error('Connection error', err.message));

module.exports = pool;
