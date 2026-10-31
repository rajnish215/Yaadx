import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {makePool} from '../src/config.js';
test('database input rejects commands; production rejects auth emulator',()=>{
 assert.throws(()=>makePool({url:'psql some-command'}),/PostgreSQL URL/);
 assert.throws(()=>makePool({url:'https://example.com'}),/PostgreSQL URL/);
 const r=spawnSync(process.execPath,['--input-type=module','-e',"import './src/config.js'"],{
   env:{...process.env,NODE_ENV:'production',DB_SCHEMA:'yaadx_prod',FIREBASE_PROJECT_ID:'demo-yaadx',FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9099'},encoding:'utf8'});
 assert.notEqual(r.status,0);assert.match(r.stderr,/Auth emulator forbidden in production/);
});
