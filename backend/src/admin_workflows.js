import {z} from 'zod';
import {rateLimit} from 'express-rate-limit';
const paging=z.object({q:z.string().max(120).default(''),page:z.coerce.number().int().min(1).max(2000).default(1),status:z.string().max(30).default('all')});
export const activityQuery=`SELECT * FROM (
 SELECT 'audit-'||a.id id,a.actor,a.action,a.target,a.created_at,'Admin action' category FROM admin_audit a
 UNION ALL SELECT 'user-'||p.uid,p.uid,'user.registered',coalesce(nullif(p.display_name,''),p.email),p.created_at,'App activity' FROM admin_profiles p
 UNION ALL SELECT 'reminder-'||r.uid||'-'||r.id,r.uid,CASE WHEN r.deleted THEN 'reminder.deleted' WHEN r.version>1 THEN 'reminder.updated' ELSE 'reminder.created' END,r.data->>'name',r.updated_at,'App activity' FROM scoped_reminders r
 UNION ALL SELECT 'ticket-'||t.id,t.uid,'support.requested',t.subject,t.created_at,'Support' FROM scoped_support_tickets t
) activity`;
export function mountAdminWorkflows(app,{run,audit,AdminError}){
 const error=(status,code)=>new AdminError(status,code);
 app.get('/v1/admin/system',async(req,res)=>res.json(await run(req,async c=>{
  const started=Date.now();await c.query('SELECT 1');
  const counts=(await c.query("SELECT count(*) FILTER(WHERE lower(email) NOT LIKE '%@example.test')::int real_users,count(*) FILTER(WHERE lower(email) LIKE '%@example.test')::int test_users,max(updated_at) last_sync FROM profiles")).rows[0];
  return {database:'connected',databaseLatencyMs:Date.now()-started,serverTime:new Date().toISOString(),uptimeSeconds:Math.floor(process.uptime()),counts,source:'Neon PostgreSQL',environment:process.env.NODE_ENV||'development',integrations:{authentication:'Firebase',ai:process.env.GEMINI_API_KEY&&process.env.GEMINI_MODEL?'configured':'not_configured',inbox:'connected',payments:'not_configured',push:'not_configured'}};
 })));
 app.get('/v1/admin/users/:uid',async(req,res)=>{
  const uid=z.string().min(1).max(128).parse(req.params.uid),{page}=paging.parse(req.query);
  res.json(await run(req,async c=>{
   const profile=(await c.query("SELECT p.*,coalesce(a.status,'active') status,coalesce(a.reason,'') reason,s.plan stored_plan,CASE WHEN s.expires_at>now() THEN s.plan ELSE 'free' END plan,s.expires_at,s.note,coalesce(s.version,0) subscription_version FROM admin_profiles p LEFT JOIN admin_accounts a USING(uid) LEFT JOIN subscriptions s USING(uid) WHERE p.uid=$1",[uid])).rows[0];
   if(!profile)throw error(404,'not_found');
   return {profile,preferences:(await c.query('SELECT alerts_enabled,updated_at FROM preferences WHERE uid=$1',[uid])).rows[0]||null,
    total:(await c.query('SELECT count(*)::int n FROM reminders WHERE uid=$1 AND NOT deleted',[uid])).rows[0].n,
    reminders:(await c.query('SELECT id,data,version,created_at,updated_at FROM reminders WHERE uid=$1 AND NOT deleted ORDER BY updated_at DESC,id LIMIT 25 OFFSET $2',[uid,(page-1)*25])).rows,
    media:(await c.query('SELECT count(*)::int files,coalesce(sum(byte_size),0)::bigint bytes FROM media WHERE uid=$1 AND ready',[uid])).rows[0],
    tickets:(await c.query('SELECT id,subject,status,created_at FROM support_tickets WHERE uid=$1 ORDER BY created_at DESC LIMIT 10',[uid])).rows};
  }));
 });
 app.get('/v1/admin/subscriptions',async(req,res)=>{
  const {q,page,status}=paging.parse(req.query);if(!['all','free','active','expiring','expired','monthly','yearly'].includes(status))throw error(400,'invalid_filter');
  res.json(await run(req,async c=>{
   const select=`SELECT p.uid,p.display_name,p.email,p.is_test,p.created_at,p.updated_at,coalesce(a.status,'active') status,CASE WHEN s.expires_at>now() THEN s.plan ELSE 'free' END plan,coalesce(s.plan,'free') stored_plan,s.expires_at,s.note,coalesce(s.version,0) subscription_version,CASE WHEN s.plan!='free' AND s.expires_at<=now() THEN 'expired' WHEN s.expires_at>now() THEN 'active' ELSE 'free' END subscription_status FROM admin_profiles p LEFT JOIN subscriptions s USING(uid) LEFT JOIN admin_accounts a USING(uid)`;
   const filter=" WHERE (email ILIKE $1 OR display_name ILIKE $1) AND ($2='all' OR subscription_status=$2 OR stored_plan=$2 OR ($2='expiring' AND subscription_status='active' AND expires_at<=now()+interval '7 days'))";
   return {total:(await c.query('SELECT count(*)::int n FROM ('+select+') s'+filter,[`%${q}%`,status])).rows[0].n,
    rows:(await c.query('SELECT * FROM ('+select+') s'+filter+' ORDER BY updated_at DESC,uid LIMIT 25 OFFSET $3',[`%${q}%`,status,(page-1)*25])).rows,
    summary:(await c.query("SELECT count(*) FILTER(WHERE s.expires_at>now() AND s.plan!='free')::int active,count(*) FILTER(WHERE s.expires_at<=now() AND s.plan!='free')::int expired,count(*) FILTER(WHERE s.expires_at>now() AND s.expires_at<=now()+interval '7 days' AND s.plan!='free')::int expiring,count(*) FILTER(WHERE s.uid IS NULL OR s.plan='free' OR s.expires_at<=now())::int free FROM admin_profiles p LEFT JOIN subscriptions s USING(uid)")).rows[0]};
  }));
 });
 app.get('/v1/admin/tickets/:id',async(req,res)=>res.json(await run(req,async c=>{
  const id=z.uuid().parse(req.params.id);const ticket=(await c.query('SELECT t.*,p.email,p.display_name FROM scoped_support_tickets t JOIN admin_profiles p USING(uid) WHERE t.id=$1',[id])).rows[0];if(!ticket)throw error(404,'not_found');
  return {ticket,messages:(await c.query('SELECT id,author,body,created_at FROM ticket_messages WHERE ticket_id=$1 ORDER BY created_at,id LIMIT 500',[id])).rows};
 })));
 app.put('/v1/admin/announcements/:id',async(req,res)=>{
  const id=z.uuid().parse(req.params.id),b=z.object({title:z.string().trim().min(3).max(120),body:z.string().trim().min(3).max(2000),baseVersion:z.number().int().positive()}).strict().parse(req.body);
  res.json(await run(req,async c=>{const r=await c.query("UPDATE announcements SET title=$2,body=$3,version=version+1 WHERE id=$1 AND version=$4 AND status!='published' RETURNING id",[id,b.title,b.body,b.baseVersion]);if(!r.rowCount)throw error(409,'draft_changed_or_published');await audit(c,req.identity.uid,'announcement.edited',id);return {ok:true};}));
 });
 app.get('/v1/admin/activity',async(req,res)=>{
  const {q,page,status}=paging.parse(req.query);res.json(await run(req,async c=>{
   const filter=" WHERE (action ILIKE $1 OR target ILIKE $1 OR actor ILIKE $1) AND ($2='all' OR category=$2)";
   return {total:(await c.query('SELECT count(*)::int n FROM ('+activityQuery+') x'+filter,[`%${q}%`,status])).rows[0].n,rows:(await c.query(activityQuery+filter+' ORDER BY created_at DESC,id LIMIT 25 OFFSET $3',[`%${q}%`,status,(page-1)*25])).rows};
  }));
 });
 app.get('/v1/admin/backups',async(req,res)=>res.json(await run(req,async c=>({rows:(await c.query('SELECT * FROM backup_exports ORDER BY created_at DESC LIMIT 50')).rows}))));
}
export function mountSupportFollowup(app,{run,AdminError}){
 app.post('/v1/community/tickets/:id/messages',rateLimit({windowMs:3600000,limit:30,keyGenerator:req=>req.identity.uid,legacyHeaders:false}),async(req,res)=>{
  const id=z.uuid().parse(req.params.id),b=z.object({id:z.uuid(),body:z.string().trim().min(1).max(2000)}).strict().parse(req.body);
  res.json(await run(req,async(c,uid)=>{
   const ticket=(await c.query('SELECT id FROM support_tickets WHERE id=$1 AND uid=$2 FOR UPDATE',[id,uid])).rows[0];if(!ticket)throw new AdminError(404,'not_found');
   const old=(await c.query('SELECT ticket_id,body FROM ticket_messages WHERE id=$1',[b.id])).rows[0];
   if(old){if(old.ticket_id!==id||old.body!==b.body)throw new AdminError(409,'idempotency_mismatch');return {ok:true};}
   await c.query("INSERT INTO ticket_messages(id,ticket_id,uid,author,body) VALUES($1,$2,$3,'user',$4)",[b.id,id,uid,b.body]);
   await c.query("UPDATE support_tickets SET status='open',version=version+1,updated_at=now() WHERE id=$1 AND uid=$2",[id,uid]);return {ok:true};
  }));
 });
}
