import {schema,runtimeRole} from './config.js';
export async function transaction(pool,uid,fn){
 const c=await pool.connect();
 try{
  await c.query('BEGIN');
  await c.query(`SET LOCAL ROLE ${runtimeRole}`);
  await c.query(`SET LOCAL search_path TO ${schema},public`);
  await c.query("SELECT set_config('app.uid',$1,true)",[uid]);
  // Serialize operations for an account; separate users never share a transaction.
  await c.query('SELECT pg_advisory_xact_lock(hashtext($1))',[`yaadx:${uid}`]);
  const result=await fn(c);
  await c.query('COMMIT');return result;
 }catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
}
