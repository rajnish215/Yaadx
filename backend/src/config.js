import dotenv from 'dotenv';
import pg from 'pg';

// Parse data, never source shell commands. Only the explicitly selected file is read.
if (process.env.YAADX_ENV_FILE) {
  const loaded = dotenv.config({path: process.env.YAADX_ENV_FILE, quiet: true});
  if (loaded.error) throw new Error('Cannot read backend environment file');
}
export const schema = process.env.DB_SCHEMA || 'yaadx_dev';
if (!/^yaadx_[a-z][a-z0-9_]{0,40}$/.test(schema)) throw new Error('Invalid DB_SCHEMA');
export const runtimeRole = `${schema}_api`;
export const production = process.env.NODE_ENV === 'production';
if (production && !process.env.DB_SCHEMA) throw new Error('Set DB_SCHEMA explicitly in production');
if (production && !process.env.FIREBASE_PROJECT_ID) throw new Error('Set FIREBASE_PROJECT_ID explicitly in production');
export const projectId = process.env.FIREBASE_PROJECT_ID || 'yaadx-8e018';
if (production && process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Auth emulator forbidden in production');
export function makePool({direct = false, url = process.env.DATABASE_URL} = {}) {
  let u;
  try { u = new URL(direct && process.env.DIRECT_DATABASE_URL || url); } catch { throw new Error('DATABASE_URL must be a PostgreSQL URL'); }
  if (!['postgres:', 'postgresql:'].includes(u.protocol) || !u.username || !u.password || !u.hostname || u.pathname.length < 2) throw new Error('Invalid PostgreSQL URL');
  if (direct && !process.env.DIRECT_DATABASE_URL && u.hostname.endsWith('.neon.tech')) u.hostname = u.hostname.replace('-pooler.', '.');
  // Do not let URL sslmode override certificate verification.
  for (const key of ['sslmode','sslcert','sslkey','sslrootcert','channel_binding']) u.searchParams.delete(key);
  return new pg.Pool({connectionString:u.toString(), ssl:{rejectUnauthorized:true}, max:direct?1:5,
    connectionTimeoutMillis:10000, idleTimeoutMillis:30000, statement_timeout:10000, query_timeout:12000,
    application_name:'yaadx-api'});
}
