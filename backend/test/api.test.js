import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import {randomUUID} from 'node:crypto';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {createApp} from '../src/app.js';
import {makePool,schema,projectId} from '../src/config.js';
import {transaction} from '../src/db.js';
import {reminderSchema} from '../src/validation.js';
const data={id:'one',name:'Ankit',relation:'Friend',phoneNumber:null,eventType:'Birthday',date:'2030-02-28',time:'18:30',note:'',memoryCaption:'',photoIds:[],voiceId:null,voiceNoteCompleted:false,messageSent:false,repeatYearly:true,advanceDays:10,voiceAlert:true,notificationEnabled:true,isCompleted:false,createdAt:'2026-01-01T00:00:00.000Z'};
test('validation rejects invalid dates, time, unknown ownership and local paths',()=>{
 assert.equal(reminderSchema.safeParse(data).success,true);
 for(const change of [{date:'2030-02-30'},{time:'25:10'},{uid:'victim'},{memoryPhotoPaths:['/private/file']},{advanceDays:11}]) assert.equal(reminderSchema.safeParse({...data,...change}).success,false);
});
test('real Firebase verifier rejects forged tokens',async()=>{
 const app=initializeApp({projectId},randomUUID());
 await assert.rejects(getAuth(app).verifyIdToken('eyJhbGciOiJub25lIn0.eyJzdWIiOiJ2aWN0aW0ifQ.'));
});
test('Neon API transactions, authorization, idempotency, concurrency and tombstones',{skip:!process.env.DATABASE_URL,timeout:90000},async()=>{
 const pool=makePool();const prefix=`test-${randomUUID()}`;const alice=`${prefix}-a`,bob=`${prefix}-b`;
 const api=createApp({pool,verifyToken:async token=>{if(token==='alice')return {uid:alice,name:'Alice'};if(token==='bob')return {uid:bob,name:'Bob'};throw Error();}});
 const a=()=>request(api);const op=()=>({operationId:randomUUID(),baseVersion:0,data});
 try{
  assert.equal((await a().get('/v1/reminders')).status,401);
  assert.equal((await a().get('/v1/reminders').set('Authorization','Bearer invalid')).status,401);
  const body=op();let r=await a().put('/v1/reminders/one').set('Authorization','Bearer alice').send(body);assert.equal(r.status,200,JSON.stringify(r.body));assert.equal(r.body.version,1);
  r=await a().put('/v1/reminders/one').set('Authorization','Bearer alice').send(body);assert.equal(r.body.version,1);
  r=await a().get('/v1/reminders').set('Authorization','Bearer bob');assert.deepEqual(r.body.reminders,[]);
  assert.equal((await a().get('/v1/reminders/one').set('Authorization','Bearer bob')).status,404);
  assert.equal((await a().put('/v1/reminders/one').set('Authorization','Bearer bob').send({...op(),baseVersion:1})).status,409);
  await transaction(pool,bob,async c=>assert.equal((await c.query('SELECT * FROM reminders')).rowCount,0));
  const updates=await Promise.all([1,2].map(n=>a().put('/v1/reminders/one').set('Authorization','Bearer alice').send({operationId:randomUUID(),baseVersion:1,data:{...data,name:`Updated ${n}`}})));
  assert.deepEqual(updates.map(r=>r.status).sort(),[200,409]);
  assert.equal((await a().put('/v1/reminders/one').set('Authorization','Bearer alice').send({...op(),data:{...data,photoIds:[randomUUID()]},baseVersion:2})).status,400);
  assert.equal((await a().put('/v1/reminders/one').set('Authorization','Bearer alice').send({operationId:randomUUID(),baseVersion:2,data:null})).body.deleted,true);
  assert.equal((await a().get('/v1/reminders/one').set('Authorization','Bearer alice')).status,404);
  assert.equal((await a().get('/v1/reminders').set('Authorization','Bearer alice')).body.reminders[0].deleted,true);
  const pref=await a().get('/v1/preferences').set('Authorization','Bearer alice');assert.equal(pref.body.version,1);
  assert.equal((await a().put('/v1/preferences').set('Authorization','Bearer alice').send({alertsEnabled:false,baseVersion:1})).body.alertsEnabled,false);
  assert.equal((await a().put('/v1/preferences').set('Authorization','Bearer alice').send({alertsEnabled:true,baseVersion:1})).status,409);
  assert.equal((await a().post('/v1/media').set('Authorization','Bearer alice').send({id:randomUUID(),kind:'voice',contentType:'audio/mp4',byteSize:20})).status,503);
 }finally{
  for(const uid of [alice,bob])await transaction(pool,uid,async c=>{for(const table of ['mutations','media','reminders','preferences','profiles'])await c.query(`DELETE FROM ${table} WHERE uid=$1`,[uid]);});
  await pool.end();
 }
});

test('media references require owner and verified object; local paths never accepted',{skip:!process.env.DATABASE_URL,timeout:60000},async()=>{
 const pool=makePool();const uid=`test-${randomUUID()}`;const other=`test-${randomUUID()}`;
 const storage={upload:async()=> 'https://storage.example/upload',download:async()=> 'https://storage.example/download',inspect:async()=>({ContentLength:100,ContentType:'image/jpeg'})};
 const api=createApp({pool,storage,verifyToken:async token=>({uid:token==='owner'?uid:other})});
 const call=(method,path,token='owner')=>request(api)[method](path).set('Authorization',`Bearer ${token}`);
 const id=randomUUID();
 try{
  const r=await call('post','/v1/media').send({id,kind:'photo',contentType:'image/jpeg',byteSize:100});assert.equal(r.status,200);assert.equal(r.body.ready,false);
  assert.equal((await call('get',`/v1/media/${id}`)).status,404);
  assert.equal((await call('post',`/v1/media/${id}/complete`,'other')).status,404);
  assert.equal((await call('post',`/v1/media/${id}/complete`)).body.ready,true);
  assert.equal((await call('get',`/v1/media/${id}`,'other')).status,404);
  assert.equal((await call('get',`/v1/media/${id}`)).body.downloadUrl,'https://storage.example/download');
  assert.equal((await call('put','/v1/reminders/one').send({operationId:randomUUID(),baseVersion:0,data:{...data,photoIds:[id]}})).status,200);
  assert.equal((await call('put','/v1/reminders/one','other').send({operationId:randomUUID(),baseVersion:0,data:{...data,photoIds:[id]}})).status,400);
  await assert.rejects(transaction(pool,uid,c=>c.query('INSERT INTO profiles(uid) VALUES($1)',[`${other}-spoof`])),e=>e.code==='42501');
 }finally{
  for(const who of [uid,other])await transaction(pool,who,async c=>{for(const t of ['mutations','media','reminders','preferences','profiles'])await c.query(`DELETE FROM ${t} WHERE uid=$1`,[who]);});
  await pool.end();
 }
});
