// server.js

require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

// --- DB pool, config comes only from environment variables ---
const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  max: 10,
  idleTimeoutMillis: 30000,
});

pool.on('error', (err) => {
  // Don't crash the whole process on an idle client error;
  // log it so it's visible in journald via systemd.
  console.error('Unexpected PG pool error:', err.message);
});

// --- Ensure table exists on boot (simple, idempotent) ---
async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS notes (
      id SERIAL PRIMARY KEY,
      content TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

// --- READ endpoint #1: health check (also proves DB connectivity) ---
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'connected' });
  } catch (err) {
    console.error('Health check DB error:', err.message);
    res.status(503).json({ status: 'error', db: 'unreachable' });
  }
});

// --- READ endpoint #2: list notes ---
app.get('/api/notes', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, content, created_at FROM notes ORDER BY id DESC LIMIT 50'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /api/notes error:', err.message);
    res.status(500).json({ error: 'internal_error' });
  }
});

// --- WRITE endpoint: insert a note ---
app.post('/api/notes', async (req, res) => {
  const { content } = req.body;
  if (!content || typeof content !== 'string' || content.trim() === '') {
    return res.status(400).json({ error: 'content is required' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO notes (content) VALUES ($1) RETURNING id, content, created_at',
      [content.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('POST /api/notes error:', err.message);
    res.status(500).json({ error: 'internal_error' });
  }
});

// --- Start server, bound to localhost only ---
const PORT = process.env.APP_PORT || 3000;
const HOST = '127.0.0.1'; // never 0.0.0.0 — Nginx handles the public side

async function start() {
  try {
    await ensureSchema();
    app.listen(PORT, HOST, () => {
      console.log(`App listening on ${HOST}:${PORT}`);
    });
  } catch (err) {
    console.error('Fatal startup error:', err.message);
    process.exit(1); // non-zero exit -> systemd Restart=on-failure kicks in
  }
}

start();

// Graceful shutdown so systemd stop/restart is clean
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing pool...');
  await pool.end();
  process.exit(0);
});
