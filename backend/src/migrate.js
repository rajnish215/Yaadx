import {readdir,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {makePool,schema,runtimeRole} from './config.js';
const pool=makePool({direct:true});
try {
 const c=await pool.connect();
 try {
  await c.query('BEGIN');
  await c.query("SELECT pg_advisory_xact_lock(hashtext($1))",[`${schema}:migrations`]);
  await c.query(`CREATE SCHEMA IF NOT EXISTS ${schema}`);
  await c.query(`SET LOCAL search_path TO ${schema},public`);
  await c.query('CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');
  const files=(await readdir(new URL('../migrations/',import.meta.url))).filter(f=>f.endsWith('.sql')).sort();
  for(const f of files){
   const sql=await readFile(new URL(`../migrations/${f}`,import.meta.url),'utf8');
   const checksum=createHash('sha256').update(sql).digest('hex');
   const existing=await c.query('SELECT checksum FROM schema_migrations WHERE version=$1',[f]);
   if(existing.rowCount){if(existing.rows[0].checksum!==checksum)throw new Error('Migration checksum mismatch');continue;}
   await c.query(sql);await c.query('INSERT INTO schema_migrations(version,checksum) VALUES($1,$2)',[f,checksum]);
   console.log(`Applied ${f}`);
  }
  if(!(await c.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[runtimeRole])).rowCount) await c.query(`CREATE ROLE ${runtimeRole} NOLOGIN NOSUPERUSER NOBYPASSRLS`);
  await c.query(`GRANT ${runtimeRole} TO CURRENT_USER`);
  await c.query(`GRANT USAGE ON SCHEMA ${schema} TO ${runtimeRole}`);
  await c.query(`GRANT SELECT,INSERT,UPDATE,DELETE ON profiles,preferences,reminders,media,mutations TO ${runtimeRole}`);
  await c.query('COMMIT');console.log('Migrations verified; restricted API role ready');
 }catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
}catch {console.error('Migration failed; transaction rolled back (details withheld to protect connection information)');process.exitCode=1;}
finally{await pool.end();}
