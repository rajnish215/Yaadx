import {mountAdmin,mountCommunity,cloudAccess,AdminError} from './admin.js';
import {mountSuggestions} from './suggestions.js';
import express from 'express';
import helmet from 'helmet';
import {rateLimit} from 'express-rate-limit';
import {createHash} from 'node:crypto';
import {z} from 'zod';
import {transaction} from './db.js';
import {idSchema,mutationSchema,mediaSchema} from './validation.js';
export class HttpError extends Error {constructor(status,code){super(code);this.status=status;this.code=code;}}
const notFound=()=>new HttpError(404,'not_found');
const view=r=>({id:r.id,data:r.data,version:r.version,deleted:r.deleted,updatedAt:r.updated_at});
export function createApp({pool,verifyToken,storage=null,suggestions=null,admin=null}){
 const app=express();app.disable('x-powered-by');app.use(helmet());app.use(express.json({limit:'96kb'}));
 app.get('/health',(_req,res)=>res.json({ok:true}));
 app.get('/ready',async(_req,res)=>{try{await pool.query('SELECT 1');res.json({ready:true});}catch{res.status(503).json({ready:false});}});
 app.use('/v1',rateLimit({windowMs:60000,limit:180,standardHeaders:'draft-8',legacyHeaders:false}));
 app.use('/v1',async(req,res,next)=>{
  res.set('Cache-Control','no-store');
  const match=/^Bearer ([^\s]+)$/.exec(req.headers.authorization||'');
  if(!match||match[1].length>8192)return res.status(401).json({error:'unauthenticated'});
  try{const token=await verifyToken(match[1]);if(!token.uid||token.uid.length>128)throw Error();req.identity=token;next();}
  catch{return res.status(401).json({error:'unauthenticated'});}
 });
 if(admin)app.use("/v1",cloudAccess(pool,admin.emails));
 const run=(req,fn)=>transaction(pool,req.identity.uid,async c=>{
  const t=req.identity;
  await c.query(`INSERT INTO profiles(uid,display_name,email) VALUES($1,$2,$3) ON CONFLICT(uid) DO UPDATE SET display_name=excluded.display_name,email=excluded.email,updated_at=now()`,[t.uid,(t.name||'').slice(0,120),(t.email||'').slice(0,320)]);
  return fn(c,t.uid);
 });
 if(admin){mountAdmin(app,{pool,...admin});mountCommunity(app,{pool,run});}
 mountSuggestions(app,suggestions,admin?async(req,outcome)=>{try{await run(req,(c,uid)=>c.query('INSERT INTO ai_usage(uid,outcome) VALUES($1,$2)',[uid,outcome]));}catch{console.error('AI usage metric could not be recorded');}}:null);
 app.get('/v1/profile',async(req,res)=>res.json(await run(req,async(c,uid)=>(await c.query('SELECT uid,display_name,email FROM profiles WHERE uid=$1',[uid])).rows[0])));
 app.get('/v1/preferences',async(req,res)=>res.json(await run(req,async(c,uid)=>{
  await c.query('INSERT INTO preferences(uid) VALUES($1) ON CONFLICT DO NOTHING',[uid]);
  const r=(await c.query('SELECT * FROM preferences WHERE uid=$1',[uid])).rows[0];return {alertsEnabled:r.alerts_enabled,version:r.version};
 })));
 app.put('/v1/preferences',async(req,res)=>{
  const b=z.object({alertsEnabled:z.boolean(),baseVersion:z.number().int().positive()}).strict().parse(req.body);
  res.json(await run(req,async(c,uid)=>{
   const r=await c.query('UPDATE preferences SET alerts_enabled=$2,version=version+1,updated_at=now() WHERE uid=$1 AND version=$3 RETURNING *',[uid,b.alertsEnabled,b.baseVersion]);
   if(!r.rowCount)throw new HttpError(409,'version_conflict');return {alertsEnabled:r.rows[0].alerts_enabled,version:r.rows[0].version};
  }));
 });
 app.get('/v1/reminders',async(req,res)=>res.json(await run(req,async(c,uid)=>{
  const r=await c.query('SELECT * FROM reminders WHERE uid=$1 ORDER BY id LIMIT 5001',[uid]);
  if(r.rowCount>5000)throw new HttpError(413,'account_limit');return {reminders:r.rows.map(view)};
 })));
 app.get('/v1/reminders/:id',async(req,res)=>{const id=idSchema.parse(req.params.id);res.json(await run(req,async(c,uid)=>{
  const r=await c.query('SELECT * FROM reminders WHERE uid=$1 AND id=$2 AND NOT deleted',[uid,id]);if(!r.rowCount)throw notFound();return view(r.rows[0]);
 }));});
 app.put('/v1/reminders/:id',async(req,res)=>{
  const id=idSchema.parse(req.params.id),b=mutationSchema.parse(req.body);
  if(b.data&&b.data.id!==id)throw new HttpError(400,'id_mismatch');
  const hash=createHash('sha256').update(JSON.stringify({id,...b})).digest('hex');
  const result=await run(req,async(c,uid)=>{
   const old=await c.query('SELECT * FROM mutations WHERE uid=$1 AND operation_id=$2',[uid,b.operationId]);
   if(old.rowCount){if(old.rows[0].request_hash!==hash)throw new HttpError(409,'idempotency_mismatch');return old.rows[0].response;}
   const current=(await c.query('SELECT * FROM reminders WHERE uid=$1 AND id=$2',[uid,id])).rows[0];
   if((current?.version||0)!==b.baseVersion)throw new HttpError(409,'version_conflict');
   if(!current&&!b.data)throw notFound();
   if(current?.deleted)throw new HttpError(409,'deleted_reminder');
   if(!current){const count=await c.query('SELECT count(*)::int AS n FROM reminders WHERE uid=$1',[uid]);if(count.rows[0].n>=5000)throw new HttpError(413,'account_limit');}
   if(b.data){
    const refs=[...b.data.photoIds,...(b.data.voiceId?[b.data.voiceId]:[])];
    if(refs.length){const media=await c.query('SELECT id,kind FROM media WHERE uid=$1 AND id=ANY($2::uuid[]) AND ready',[uid,refs]);
     const photos=new Set(media.rows.filter(r=>r.kind==='photo').map(r=>r.id));const voices=new Set(media.rows.filter(r=>r.kind==='voice').map(r=>r.id));
     if(b.data.photoIds.some(id=>!photos.has(id))||(b.data.voiceId&&!voices.has(b.data.voiceId)))throw new HttpError(400,'invalid_media');}
   }
   const r=await c.query(`INSERT INTO reminders(uid,id,data) VALUES($1,$2,$3) ON CONFLICT(uid,id) DO UPDATE SET data=excluded.data,deleted=$4,version=reminders.version+1,updated_at=now() RETURNING *`,[uid,id,b.data||current.data,!b.data]);
   const response=view(r.rows[0]);await c.query('INSERT INTO mutations(uid,operation_id,request_hash,response) VALUES($1,$2,$3,$4)',[uid,b.operationId,hash,response]);return response;
  });res.json(result);
 });
 app.post('/v1/media',async(req,res)=>{
  const b=mediaSchema.parse(req.body);if(!storage)throw new HttpError(503,'media_storage_not_configured');
  const r=await run(req,async(c,uid)=>{
   const key=`yaadx/${createHash('sha256').update(uid).digest('hex')}/${b.id}`;
   await c.query('INSERT INTO media(uid,id,object_key,kind,content_type,byte_size) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(uid,id) DO NOTHING',[uid,b.id,key,b.kind,b.contentType,b.byteSize]);
   const item=(await c.query('SELECT * FROM media WHERE uid=$1 AND id=$2',[uid,b.id])).rows[0];
   if(item.kind!==b.kind||item.content_type!==b.contentType||item.byte_size!==b.byteSize)throw new HttpError(409,'media_conflict');
   return item;
  });
  res.json({id:r.id,ready:r.ready,uploadUrl:r.ready?null:await storage.upload(r.object_key,r.content_type,r.byte_size)});
 });
 app.post('/v1/media/:id/complete',async(req,res)=>{
  const id=z.uuid().parse(req.params.id);if(!storage)throw new HttpError(503,'media_storage_not_configured');
  const item=await run(req,async(c,uid)=>(await c.query('SELECT * FROM media WHERE uid=$1 AND id=$2',[uid,id])).rows[0]);if(!item)throw notFound();
  let head;try{head=await storage.inspect(item.object_key);}catch{throw new HttpError(409,'upload_incomplete');}
  if(head.ContentLength!==item.byte_size||head.ContentType!==item.content_type)throw new HttpError(400,'media_size_or_type_mismatch');
  await run(req,(c,uid)=>c.query('UPDATE media SET ready=true WHERE uid=$1 AND id=$2',[uid,id]));res.json({id,ready:true});
 });
 app.get('/v1/media/:id',async(req,res)=>{
  const id=z.uuid().parse(req.params.id);if(!storage)throw new HttpError(503,'media_storage_not_configured');
  const item=await run(req,async(c,uid)=>(await c.query('SELECT * FROM media WHERE uid=$1 AND id=$2 AND ready',[uid,id])).rows[0]);if(!item)throw notFound();
  res.json({id,downloadUrl:await storage.download(item.object_key),contentType:item.content_type,byteSize:item.byte_size});
 });
 app.use((_req,res)=>res.status(404).json({error:'not_found'}));
 app.use((e,_req,res,_next)=>{
  const status=e instanceof z.ZodError?400:e.status||503;
  res.status(status).json({error:e instanceof z.ZodError?'invalid_input':(e instanceof HttpError||e instanceof AdminError)?e.code:status===413?'body_too_large':'service_unavailable'});
 });return app;
}
