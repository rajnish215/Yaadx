import {mountAdminWorkflows,mountSupportFollowup,activityQuery} from './admin_workflows.js';
import {randomUUID,createHash} from 'node:crypto';
import { z } from "zod";
import { rateLimit } from "express-rate-limit";
import { schema } from "./config.js";
import { transaction } from "./db.js";
const emailSet = (values) =>
  new Set(
    values
      .split(",")
      .map((v) => v.trim().toLowerCase())
      .filter(Boolean),
  );
export function adminAllowed(
  identity,
  emails = process.env.ADMIN_EMAILS || "",
) {
  return (
    emailSet(emails).has((identity.email || "").toLowerCase())
  );
}
export async function adminTransaction(pool, actor, fn) {
  const c = await pool.connect();
  try {
    await c.query("BEGIN");
    await c.query(`SET LOCAL ROLE ${schema}_admin`);
    await c.query(`SET LOCAL search_path TO ${schema},public`);
    await c.query("SELECT set_config('app.uid',$1,true)", [actor]);
    const result = await fn(c);
    await c.query("COMMIT");
    return result;
  } catch (e) {
    await c.query("ROLLBACK");
    throw e;
  } finally {
    c.release();
  }
}
export class AdminError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}
const error = (status, code) => new AdminError(status, code);
const audit = (c, uid, action, target = "") =>
  c.query("INSERT INTO admin_audit(actor,action,target) VALUES($1,$2,$3)", [
    uid,
    action,
    target,
  ]);
const paging = z.object({
  q: z.string().max(120).default(""),
  page: z.coerce.number().int().min(1).max(2000).default(1),
  status:z.string().max(30).default("all"),
});
const version = z.number().int().positive();
const uuid = z.uuid();
const uidType = z.string().min(1).max(128);
export function mountAdmin(
  app,
  { pool, emails = process.env.ADMIN_EMAILS || "" },
) {
  app.use(
    "/v1/admin",
    rateLimit({
      windowMs: 60000,
      limit: 120,
      keyGenerator: (req) => req.identity.uid,
      standardHeaders: "draft-8",
      legacyHeaders: false,
    }),
  );
  app.use("/v1/admin", (req, res, next) => {
    if (!adminAllowed(req.identity, emails))
      return res.status(403).json({ error: "admin_required" });
    next();
  });
  const run = (req, fn) => adminTransaction(pool, req.identity.uid, async c=>{
    const includeTest=z.enum(['0','1']).default('0').parse(req.query.includeTest);
    await c.query("SELECT set_config('app.include_test',$1,true)",[includeTest==='1'?'true':'false']);
    return fn(c);
  });
  mountAdminWorkflows(app,{run,audit,AdminError});
  app.get("/v1/admin/me", (req, res) =>
    res.json({
      email: req.identity.email,
      name: req.identity.name || "Admin",
      role: "Super Admin",
    }),
  );
  app.get("/v1/admin/dashboard", async (req, res) =>
    res.json(
      await run(req, async (c) => {
        const totals = (
          await c.query(`SELECT (SELECT count(*)::int FROM admin_profiles) users,
   (SELECT count(*)::int FROM scoped_reminders WHERE NOT deleted) reminders,
   (SELECT count(*)::int FROM scoped_subscriptions WHERE plan!='free' AND expires_at>now()) subscriptions,
   (SELECT count(*)::int FROM scoped_support_tickets WHERE status!='resolved') tickets,
   (SELECT count(*)::int FROM announcements WHERE status='published') announcements,
   (SELECT count(*)::int FROM scoped_announcement_receipts) reads,
   (SELECT count(*)::int FROM scoped_admin_accounts WHERE status='suspended') suspended,
   (SELECT count(*)::int FROM scoped_ai_usage WHERE outcome='success') ai_success,
   (SELECT count(*)::int FROM scoped_ai_usage WHERE outcome='failed') ai_failed,
   (SELECT count(*)::int FROM admin_profiles WHERE created_at>=date_trunc('month',now())) new_users`)
        ).rows[0];
        const growth = (
          await c.query(
            `SELECT to_char(m,'Mon') label, count(p.uid)::int value FROM generate_series(date_trunc('month',now())-interval '5 months',date_trunc('month',now()),interval '1 month') m LEFT JOIN admin_profiles p ON date_trunc('month',p.created_at)=m GROUP BY m ORDER BY m`,
          )
        ).rows;
        const plans = (
          await c.query(
            `SELECT CASE WHEN s.expires_at>now() THEN s.plan ELSE 'free' END name,count(*)::int value FROM admin_profiles p LEFT JOIN scoped_subscriptions s ON p.uid=s.uid GROUP BY 1`,
          )
        ).rows;
        const ticketStatus = (
          await c.query(
            "SELECT status name,count(*)::int value FROM scoped_support_tickets GROUP BY status",
          )
        ).rows;
        const recent = (
          await c.query(
            `SELECT p.uid,p.display_name,p.email,p.created_at,p.updated_at,coalesce(a.status,'active') status,CASE WHEN s.expires_at>now() THEN s.plan ELSE 'free' END plan FROM admin_profiles p LEFT JOIN scoped_admin_accounts a USING(uid) LEFT JOIN scoped_subscriptions s USING(uid) ORDER BY p.created_at DESC LIMIT 5`,
          )
        ).rows;
        const activity = (
          await c.query(
            activityQuery+" ORDER BY created_at DESC LIMIT 8",
          )
        ).rows;
        const upcoming = (
          await c.query(
            `SELECT * FROM (SELECT id,uid,data->>'name' name,data->>'eventType' type,data->>'date' date,data->>'time' time,(data->>'repeatYearly')::boolean repeat_yearly,next_event_date((data->>'date')::date,coalesce((data->>'repeatYearly')::boolean,false),(now() AT TIME ZONE 'Asia/Kolkata')::date) next_date FROM scoped_reminders WHERE NOT deleted AND coalesce((data->>'isCompleted')::boolean,false)=false) events WHERE next_date>=(now() AT TIME ZONE 'Asia/Kolkata')::date ORDER BY next_date,time,id LIMIT 6`,
          )
        ).rows;
        return {
          totals,
          growth,
          plans,
          ticketStatus,
          recent,
          activity,
          upcoming,
          serverTime: new Date().toISOString(),
          upcomingLimited: false,
          source: {database:"Neon PostgreSQL",scope:req.query.includeTest==='1'?"All accounts including test records":"Real accounts",testAccounts:(await c.query("SELECT count(*)::int n FROM profiles WHERE lower(email) LIKE '%@example.test'")).rows[0].n},
          trends:(await c.query("SELECT to_char(d,'DD Mon') label,(SELECT count(*)::int FROM scoped_reminders r WHERE r.created_at::date=d::date) reminders,(SELECT count(*)::int FROM scoped_support_tickets t WHERE t.created_at::date=d::date) tickets,(SELECT count(*)::int FROM scoped_ai_usage a WHERE a.created_at::date=d::date AND outcome='success') ai FROM generate_series(current_date-13,current_date,interval '1 day') d ORDER BY d")).rows,
          notificationDelivery: null,
          revenue: null,
        };
      }),
    ),
  );
  app.get('/v1/admin/users',async(req,res)=>{
    const {q,page,status}=paging.parse(req.query);
    if(!['all','active','suspended'].includes(status))throw error(400,'invalid_filter');
    res.json(await run(req,async c=>{
      const args=[`%${q}%`,status];
      const base=" FROM admin_profiles p LEFT JOIN admin_accounts a USING(uid) LEFT JOIN subscriptions s USING(uid) ";
      const where=" WHERE (p.email ILIKE $1 OR p.display_name ILIKE $1 OR p.uid ILIKE $1) AND ($2='all' OR coalesce(a.status,'active')=$2)";
      return {total:(await c.query('SELECT count(*)::int n'+base+where,args)).rows[0].n,
      rows:(await c.query("SELECT p.*,coalesce(a.status,'active') status,coalesce(a.reason,'') reason,CASE WHEN s.expires_at>now() THEN s.plan ELSE 'free' END plan,s.expires_at,s.note,coalesce(s.version,0) subscription_version,(SELECT count(*)::int FROM reminders r WHERE r.uid=p.uid AND NOT deleted) reminder_count"+base+where+' ORDER BY p.created_at DESC,p.uid LIMIT 25 OFFSET $3',[...args,(page-1)*25])).rows};
    }));
  });
  app.patch("/v1/admin/users/:uid", async (req, res) => {
    const uid = uidType.parse(req.params.uid),
      b = z
        .object({
          status: z.enum(["active", "suspended"]),
          reason: z.string().trim().min(3).max(500),
        })
        .strict()
        .parse(req.body);
    if (uid === req.identity.uid)
      return res.status(400).json({ error: "cannot_suspend_self" });
    res.json(
      await run(req, async (c) => {
        const p = (
          await c.query("SELECT email FROM admin_profiles WHERE uid=$1", [uid])
        ).rows[0];
        if (!p) throw error(404, "not_found");
        if (emailSet(emails).has(p.email.toLowerCase()))
          throw error(400, "protected_admin");
        await c.query(
          "INSERT INTO admin_accounts(uid,status,reason) VALUES($1,$2,$3) ON CONFLICT(uid) DO UPDATE SET status=$2,reason=$3,updated_at=now()",
          [uid, b.status, b.reason],
        );
        await audit(c, req.identity.uid, `user.${b.status}`, uid);
        return { ok: true };
      }),
    );
  });
  app.put("/v1/admin/subscriptions/:uid", async (req, res) => {
    const uid = uidType.parse(req.params.uid),
      b = z
        .object({
          plan: z.enum(["free", "monthly", "yearly"]),
          expiresAt: z.iso.datetime().nullable(),
          note: z.string().trim().min(3).max(500),
          baseVersion: z.number().int().min(0),
        })
        .strict()
        .parse(req.body);
    if (
      b.plan !== "free" &&
      (!b.expiresAt || Date.parse(b.expiresAt) <= Date.now())
    )
      return res.status(400).json({ error: "future_expiry_required" });
    res.json(
      await run(req, async (c) => {
        await c.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
          `subscription:${uid}`,
        ]);
        if (
          !(await c.query("SELECT 1 FROM admin_profiles WHERE uid=$1", [uid]))
            .rowCount
        )
          throw error(404, "not_found");
        const old = (
          await c.query("SELECT version FROM scoped_subscriptions WHERE uid=$1", [uid])
        ).rows[0];
        if ((old?.version || 0) !== b.baseVersion)
          throw error(409, "version_conflict");
        await c.query(
          `INSERT INTO subscriptions(uid,plan,expires_at,note) VALUES($1,$2,$3,$4) ON CONFLICT(uid) DO UPDATE SET plan=$2,expires_at=$3,note=$4,version=subscriptions.version+1,updated_at=now()`,
          [uid, b.plan, b.plan === "free" ? null : b.expiresAt, b.note],
        );
        await audit(c, req.identity.uid, "subscription.manual_update", uid);
        return { ok: true };
      }),
    );
  });
  app.get('/v1/admin/tickets',async(req,res)=>{
    const {q,page,status}=paging.parse(req.query);
    if(!['all','open','in_progress','resolved'].includes(status))throw error(400,'invalid_filter');
    res.json(await run(req,async c=>{
      const base=" FROM scoped_support_tickets t JOIN admin_profiles p USING(uid) WHERE (t.subject ILIKE $1 OR p.email ILIKE $1 OR p.display_name ILIKE $1) AND ($2='all' OR t.status=$2)";
      return {total:(await c.query('SELECT count(*)::int n'+base,[`%${q}%`,status])).rows[0].n,
      rows:(await c.query('SELECT t.*,p.email,p.display_name'+base+' ORDER BY t.updated_at DESC,t.id LIMIT 25 OFFSET $3',[`%${q}%`,status,(page-1)*25])).rows,
      summary:(await c.query("SELECT count(*) FILTER(WHERE status='open')::int open,count(*) FILTER(WHERE status='in_progress')::int in_progress,count(*) FILTER(WHERE status='resolved')::int resolved FROM scoped_support_tickets")).rows[0]};
    }));
  });
  app.patch("/v1/admin/tickets/:id", async (req, res) => {
    const id = uuid.parse(req.params.id),
      b = z
        .object({
          status: z.enum(["open", "in_progress", "resolved"]),
          reply: z.string().trim().max(4000),
          baseVersion: version,
        })
        .strict()
        .parse(req.body);
    res.json(
      await run(req, async (c) => {
        const r = await c.query(
          "UPDATE support_tickets SET status=$2,reply=CASE WHEN $3='' THEN reply ELSE $3 END,version=version+1,updated_at=now() WHERE id=$1 AND version=$4 RETURNING id",
          [id, b.status, b.reply, b.baseVersion],
        );
        if (!r.rowCount) throw error(409, "version_conflict");
        if(b.reply){const ticket=(await c.query('SELECT uid FROM support_tickets WHERE id=$1',[id])).rows[0];await c.query("INSERT INTO ticket_messages(id,ticket_id,uid,author,body) VALUES($1,$2,$3,'admin',$4)",[randomUUID(),id,ticket.uid,b.reply]);}
        await audit(c, req.identity.uid, "ticket.updated", id);
        return { ok: true };
      }),
    );
  });
  app.get('/v1/admin/announcements',async(req,res)=>{
    const {q,page,status}=paging.parse(req.query);
    if(!['all','draft','published','withdrawn'].includes(status))throw error(400,'invalid_filter');
    res.json(await run(req,async c=>{
      const where=" WHERE (a.title ILIKE $1 OR a.body ILIKE $1) AND ($2='all' OR a.status=$2)";
      return {total:(await c.query('SELECT count(*)::int n FROM announcements a'+where,[`%${q}%`,status])).rows[0].n,
      rows:(await c.query('SELECT a.*,(SELECT count(*)::int FROM scoped_announcement_receipts r WHERE r.announcement_id=a.id) reads FROM announcements a'+where+' ORDER BY a.created_at DESC,a.id LIMIT 25 OFFSET $3',[`%${q}%`,status,(page-1)*25])).rows,
      summary:(await c.query("SELECT count(*) FILTER(WHERE status='draft')::int draft,count(*) FILTER(WHERE status='published')::int published,count(*) FILTER(WHERE status='withdrawn')::int withdrawn FROM announcements")).rows[0]};
    }));
  });
  app.post("/v1/admin/announcements", async (req, res) => {
    const b = z
      .object({
        id: uuid,
        title: z.string().trim().min(3).max(120),
        body: z.string().trim().min(3).max(2000),
      })
      .strict()
      .parse(req.body);
    res.json(
      await run(req, async (c) => {
        const r = await c.query(
          "INSERT INTO announcements(id,title,body,created_by) VALUES($1,$2,$3,$4) ON CONFLICT(id) DO NOTHING RETURNING id",
          [b.id, b.title, b.body, req.identity.uid],
        );
        if (r.rowCount)
          await audit(c, req.identity.uid, "announcement.drafted", b.id);
        else {
          const old = (
            await c.query("SELECT title,body FROM announcements WHERE id=$1", [
              b.id,
            ])
          ).rows[0];
          if (!old || old.title !== b.title || old.body !== b.body)
            throw error(409, "idempotency_mismatch");
        }
        return { ok: true };
      }),
    );
  });
  app.patch("/v1/admin/announcements/:id", async (req, res) => {
    const id = uuid.parse(req.params.id),
      b = z
        .object({
          status: z.enum(["published", "withdrawn"]),
          baseVersion: version,
        })
        .strict()
        .parse(req.body);
    res.json(
      await run(req, async (c) => {
        const r = await c.query(
          "UPDATE announcements SET status=$2,published_at=CASE WHEN $2='published' THEN coalesce(published_at,now()) ELSE published_at END,version=version+1 WHERE id=$1 AND version=$3 RETURNING id",
          [id, b.status, b.baseVersion],
        );
        if (!r.rowCount) throw error(409, "version_conflict");
        await audit(c, req.identity.uid, `announcement.${b.status}`, id);
        return { ok: true };
      }),
    );
  });
  app.get("/v1/admin/logs", async (req, res) => {
    const { q, page } = paging.parse(req.query);
    res.json(
      await run(req, async (c) => ({
        rows: (
          await c.query(
            "SELECT * FROM admin_audit WHERE action ILIKE $1 OR target ILIKE $1 ORDER BY id DESC LIMIT 50 OFFSET $2",
            [`%${q}%`, (page - 1) * 50],
          )
        ).rows,
      })),
    );
  });
  app.get("/v1/admin/settings", async (req, res) =>
    res.json(
      await run(req, async (c) => ({
        ...(await c.query("SELECT * FROM app_settings")).rows[0],
        security: {
          adminEmails: [...emailSet(emails)],
          verifiedEmailRequired: false,
          authentication: "Firebase ID tokens",
          databaseIsolation: "PostgreSQL RLS",
          aiConfigured: !!(
            process.env.GEMINI_API_KEY && process.env.GEMINI_MODEL
          ),
          pushConfigured: false,
          paymentsConfigured: false,
        },
      })),
    ),
  );
  app.put("/v1/admin/settings", async (req, res) => {
    const b = z
      .object({
        supportEmail: z.union([z.email(), z.literal("")]),
        maintenanceMessage: z.string().trim().max(300),
        baseVersion: version,
      })
      .strict()
      .parse(req.body);
    res.json(
      await run(req, async (c) => {
        const r = await c.query(
          "UPDATE app_settings SET support_email=$1,maintenance_message=$2,version=version+1,updated_at=now() WHERE singleton AND version=$3 RETURNING version",
          [b.supportEmail, b.maintenanceMessage, b.baseVersion],
        );
        if (!r.rowCount) throw error(409, "version_conflict");
        await audit(c, req.identity.uid, "settings.updated");
        return { ok: true };
      }),
    );
  });
  app.get("/v1/admin/export", async (req, res) => {
    const result = await run(req, async (c) => {
      const result = {
        format: "yaadx-application-export-v2",
        createdAt: new Date().toISOString(),
        limitations:
          "Application records only. No Firebase passwords, media binaries, or database roles. Not a full disaster-recovery backup.",
        tables: {},
      };
      for (const table of [
        "profiles",
        "preferences",
        "reminders",
        "subscriptions",
        "support_tickets",
        "announcements",
        "admin_accounts", "media", "announcement_receipts", "ticket_messages", "app_settings", "ai_usage", "admin_audit",
      ]) {
        const source=table==='profiles'?'admin_profiles':['reminders','subscriptions','support_tickets','admin_accounts','media','announcement_receipts','ai_usage'].includes(table)?'scoped_'+table:table;
        const filter=['ticket_messages','preferences'].includes(table)?' WHERE uid IN (SELECT uid FROM admin_profiles)':'';
        const rows=(await c.query(`SELECT * FROM ${source}${filter} LIMIT 10001`)).rows;
        if (rows.length > 10000) throw error(413, "export_too_large");
        result.tables[table] = rows;
      }
      result.recordCount=Object.values(result.tables).reduce((n,rows)=>n+rows.length,0);
      result.checksum=createHash('sha256').update(JSON.stringify(result.tables)).digest('hex');
      result.id=randomUUID();result.includeTest=req.query.includeTest==='1';
      await c.query('INSERT INTO backup_exports(id,actor,record_count,checksum,include_test) VALUES($1,$2,$3,$4,$5)',[result.id,req.identity.uid,result.recordCount,result.checksum,result.includeTest]);
      await audit(c, req.identity.uid, "backup.exported",result.id);
      return result;
    });
    res
      .set(
        "Content-Disposition",
        'attachment; filename="yaadx-application-export.json"',
      )
      .json(result);
  });
}
export function mountCommunity(app, { pool, run }) {
  mountSupportFollowup(app,{run,AdminError});
  app.get("/v1/community", async (req, res) =>
    res.json(
      await run(req, async (c, uid) => ({
        announcements: (
          await c.query(
            `SELECT a.id,a.title,a.body,a.published_at,EXISTS(SELECT 1 FROM announcement_receipts r WHERE r.announcement_id=a.id AND r.uid=$1) is_read FROM announcements a WHERE status='published' ORDER BY published_at DESC LIMIT 50`,
            [uid],
          )
        ).rows,
        tickets: (
          await c.query(
            "SELECT t.id,t.subject,t.message,t.status,t.reply,t.created_at,t.updated_at,coalesce((SELECT json_agg(m ORDER BY m.created_at) FROM (SELECT id,author,body,created_at FROM ticket_messages WHERE ticket_id=t.id ORDER BY created_at DESC LIMIT 100) m),'[]'::json) messages FROM support_tickets t WHERE t.uid=$1 ORDER BY t.created_at DESC LIMIT 50",
            [uid],
          )
        ).rows,
        subscription: (
          await c.query(
            "SELECT CASE WHEN expires_at>now() THEN plan ELSE 'free' END plan,expires_at FROM subscriptions WHERE uid=$1",
            [uid],
          )
        ).rows[0] || { plan: "free", expires_at: null },
        settings: (
          await c.query(
            "SELECT support_email,maintenance_message FROM app_settings",
          )
        ).rows[0],
      })),
    ),
  );
  app.post(
    "/v1/community/tickets",
    rateLimit({
      windowMs: 3600000,
      limit: 10,
      keyGenerator: (req) => req.identity.uid,
      legacyHeaders: false,
    }),
    async (req, res) => {
      const b = z
        .object({
          id: uuid,
          subject: z.string().trim().min(3).max(120),
          message: z.string().trim().min(3).max(2000),
        })
        .strict()
        .parse(req.body);
      res.json(
        await run(req, async (c, uid) => {
          await c.query(
            "INSERT INTO support_tickets(id,uid,subject,message) VALUES($1,$2,$3,$4) ON CONFLICT(id) DO NOTHING",
            [b.id, uid, b.subject, b.message],
          );
          const old = (
            await c.query(
              "SELECT subject,message FROM support_tickets WHERE id=$1 AND uid=$2",
              [b.id, uid],
            )
          ).rows[0];
          if (!old || old.subject !== b.subject || old.message !== b.message)
            throw error(409, "idempotency_mismatch");
          return { ok: true };
        }),
      );
    },
  );
  app.post("/v1/community/announcements/:id/read", async (req, res) => {
    const id = uuid.parse(req.params.id);
    res.json(
      await run(req, async (c, uid) => {
        if (
          !(
            await c.query(
              "SELECT 1 FROM announcements WHERE id=$1 AND status='published'",
              [id],
            )
          ).rowCount
        )
          throw error(404, "not_found");
        await c.query(
          "INSERT INTO announcement_receipts(uid,announcement_id) VALUES($1,$2) ON CONFLICT DO NOTHING",
          [uid, id],
        );
        return { ok: true };
      }),
    );
  });
}
export function cloudAccess(pool, emails) {
  return async (req, res, next) => {
    if (adminAllowed(req.identity, emails)) return next();
    const suspended = await transaction(
      pool,
      req.identity.uid,
      async (c) =>
        (
          await c.query(
            "SELECT 1 FROM admin_accounts WHERE uid=$1 AND status='suspended'",
            [req.identity.uid],
          )
        ).rowCount,
    );
    if (suspended)
      return res.status(403).json({ error: "cloud_access_suspended" });
    next();
  };
}
