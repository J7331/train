// Train sync: one encrypted backup per sync key. The server only ever sees ciphertext.
// Each backup lives in its own Durable Object, so reads and writes are strongly consistent.
import { DurableObject } from 'cloudflare:workers';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Base',
  'Access-Control-Max-Age': '86400',
};
const H = { ...CORS, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: H });
const CHUNK = 900_000; // stay under the per-row size limit

export class SyncBox extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS meta (k INTEGER PRIMARY KEY, saved INTEGER NOT NULL, n INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS part (i INTEGER PRIMARY KEY, data TEXT NOT NULL)');
  }
  read() {
    const m = this.sql.exec('SELECT saved, n FROM meta WHERE k = 1').toArray()[0];
    if (!m) return null;
    const body = this.sql.exec('SELECT data FROM part WHERE i < ? ORDER BY i', m.n).toArray().map(r => r.data).join('');
    return { saved: m.saved, body };
  }
  async fetch(req) {
    if (req.method === 'GET') {
      const cur = this.read();
      return cur ? new Response(cur.body, { headers: H }) : json({ error: 'none' }, 404);
    }
    // PUT: only accept it if the client saw the latest version; otherwise hand the latest back to merge
    const base = Number(req.headers.get('X-Base') || 0), body = await req.text(), o = JSON.parse(body);
    const cur = this.read();
    if (cur && cur.saved !== base) return new Response(cur.body, { status: 409, headers: H });
    const parts = []; for (let i = 0; i < body.length; i += CHUNK) parts.push(body.slice(i, i + CHUNK));
    this.ctx.storage.transactionSync(() => {
      this.sql.exec('DELETE FROM part');
      parts.forEach((p, i) => this.sql.exec('INSERT INTO part (i, data) VALUES (?, ?)', i, p));
      this.sql.exec('INSERT OR REPLACE INTO meta (k, saved, n) VALUES (1, ?, ?)', o.saved, parts.length);
    });
    return json({ ok: true, saved: o.saved });
  }
}

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const m = new URL(req.url).pathname.match(/^\/v1\/([0-9a-f]{64})$/);
    if (!m) return json({ error: 'not found' }, 404);
    if (req.method === 'PUT') {
      const len = Number(req.headers.get('Content-Length') || 0);
      if (len > 8_000_000) return json({ error: 'too big' }, 413);
      const body = await req.text();
      if (body.length > 8_000_000) return json({ error: 'too big' }, 413);
      let o; try { o = JSON.parse(body); } catch { return json({ error: 'bad json' }, 400); }
      if (!o || o.v !== 1 || typeof o.saved !== 'number' || typeof o.iv !== 'string' || typeof o.ct !== 'string') return json({ error: 'bad body' }, 400);
      const stub = env.BOX.get(env.BOX.idFromName(m[1]));
      return stub.fetch(new Request(req.url, { method: 'PUT', headers: req.headers, body }));
    }
    if (req.method === 'GET') return env.BOX.get(env.BOX.idFromName(m[1])).fetch(req);
    return json({ error: 'method' }, 405);
  },
};
