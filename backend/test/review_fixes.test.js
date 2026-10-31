import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import request from 'supertest';
import {makePool,schema} from '../src/config.js';
import {transaction} from '../src/db.js';
import {adminTransaction} from '../src/admin.js';
import {createApp} from '../src/app.js';

test('forward migration preserves legacy support replies and future-year dates',{
 skip:!process.env.DATABASE_URL||!schema.startsWith('yaadx_admin_check_'),timeout:60000,
},async()=>{
 const pool=makePool({direct:true}),uid='review-'+randomUUID(),ticket=randomUUID();
 try {
  await transaction(pool,uid,async c=>{
   await c.query('INSERT INTO profiles(uid,email) VALUES($1,$2)',[uid,'review@sample.invalid']);
   await c.query('INSERT INTO support_tickets(id,uid,subject,message,reply) VALUES($1,$2,$3,$4,$5)',[ticket,uid,'Legacy request','Original question','Historical answer']);
   await c.query("INSERT INTO ticket_messages(id,ticket_id,uid,author,body) VALUES($1,$2,$3,'user','New follow-up')",[randomUUID(),ticket,uid]);
  });
  const sql=await readFile(new URL('../migrations/004_review_fixes.sql',import.meta.url),'utf8');
  const c=await pool.connect();
  try {await c.query('BEGIN');await c.query(`SET LOCAL search_path TO ${schema},public`);await c.query(sql);await c.query(sql);await c.query('COMMIT');}
  catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
  await adminTransaction(pool,uid,async c=>{
   const messages=(await c.query('SELECT author,body FROM ticket_messages WHERE ticket_id=$1 ORDER BY created_at',[ticket])).rows;
   assert.deepEqual(messages,[{author:'admin',body:'Historical answer'},{author:'user',body:'New follow-up'}]);
   for(const [original,reference,expected] of [
    ['2028-11-01','2026-10-26','2028-11-01'],
    ['2000-02-29','2027-02-01','2027-02-28'],
    ['2000-02-29','2027-03-01','2028-02-29'],
    ['2028-02-29','2026-10-26','2028-02-29'],
   ]) assert.equal((await c.query('SELECT next_event_date($1::date,true,$2::date)::text d',[original,reference])).rows[0].d,expected);
  });
  const app=createApp({pool,verifyToken:async()=>({uid,email:'review-admin@sample.invalid'}),admin:{emails:'review-admin@sample.invalid'}});
  const response=await request(app).patch('/v1/admin/tickets/'+ticket).set('Authorization','Bearer review').send({status:'resolved',reply:'',baseVersion:1});
  assert.equal(response.status,200);
  await transaction(pool,uid,async c=>{
   assert.equal((await c.query('SELECT reply FROM support_tickets WHERE id=$1',[ticket])).rows[0].reply,'Historical answer');
   assert.equal((await c.query('SELECT count(*)::int n FROM ticket_messages WHERE ticket_id=$1',[ticket])).rows[0].n,2);
  });
 } finally {await pool.end();}
});
