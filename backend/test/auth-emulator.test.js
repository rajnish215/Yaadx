import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {makePool} from '../src/config.js';
import {transaction} from '../src/db.js';
const run=process.env.RUN_AUTH_EMULATOR_TESTS==='true';
test('Firebase Auth emulator tokens traverse real HTTP API and Neon',{skip:!run,timeout:60000},async()=>{
 const base='http://127.0.0.1:8081';const authBase='http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
 const users=[];
 const auth=async(action,body)=>{const res=await fetch(`${authBase}/accounts:${action}?key=demo-key`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});assert.equal(res.status,200);return res.json();};
 const call=async(path,token,method='GET',body)=>{const r=await fetch(base+path,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()};};
 try{
  for(let n=0;n<2;n++)users.push(await auth('signUp',{email:`qa-${randomUUID()}@example.test`,password:'LocalTest123!',returnSecureToken:true}));
  const [a,b]=users;
  assert.equal((await call('/v1/profile',a.idToken)).data.uid,a.localId);
  assert.equal((await call('/v1/profile',b.idToken)).data.uid,b.localId);
  assert.equal((await call('/v1/reminders',a.idToken)).status,200);
  assert.equal((await call('/v1/reminders',a.idToken+'tampered')).status,401);
  assert.equal((await fetch(base+'/ready')).status,200);
 }finally{
  const pool=makePool();
  for(const u of users){
   await auth('delete',{idToken:u.idToken});
   await transaction(pool,u.localId,async c=>{for(const t of ['mutations','media','reminders','preferences','profiles'])await c.query(`DELETE FROM ${t} WHERE uid=$1`,[u.localId]);});
  }await pool.end();
 }
});
