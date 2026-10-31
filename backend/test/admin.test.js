import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import { randomUUID } from "node:crypto";
import { createApp } from "../src/app.js";
import { adminAllowed, adminTransaction } from "../src/admin.js";
import { makePool, schema } from "../src/config.js";
import { transaction } from "../src/db.js";

test("admin access requires an exact email allowlist match from authenticated identity",()=>{
 const emails='ankitkr7488.01@gmail.com';
 assert.equal(adminAllowed({email:emails,email_verified:false},emails),true);
 assert.equal(adminAllowed({email:emails,email_verified:true},emails),true);
 for(const identity of [{email:'other@example.test'},{email:emails+'.evil'},{admin:true},{}])assert.equal(adminAllowed(identity,emails),false);
});

test(
  "admin and app lifecycle: authorization, RLS, conflicts, inbox and audit",
  {
    skip: !process.env.DATABASE_URL || !schema.startsWith("yaadx_admin_check_"),
    timeout: 120000,
  },
  async () => {
    const pool = makePool();
    const prefix = "admin-test-" + randomUUID();
    const admin = prefix + "-admin",
      alice = prefix + "-alice",
      bob = prefix + "-bob";
    const identities = {
      admin: {
        uid: admin,
        email: "admin@sample.invalid",
        email_verified: true,
        name: "Admin",
      },
      alice: { uid: alice, email: "alice@sample.invalid" },
      bob: { uid: bob, email: "bob@sample.invalid" },
      unverified: {
        uid: admin,
        email: "admin@sample.invalid",
        email_verified: false,
      },
    };
    const app = createApp({
      pool,
      admin: { emails: "admin@sample.invalid" },
      verifyToken: async (t) => {
        if (!identities[t]) throw Error();
        return identities[t];
      },
      suggestions: async () => ({
        wish: "Happy birthday, wishing you a wonderful day!",
        gifts: [1, 2, 3].map((n) => ({
          title: `Gift ${n}`,
          reason: "A thoughtful personal gift.",
        })),
      }),
    });
    const call = (method, path, who = "admin") =>
      request(app)[method](path).set("Authorization", `Bearer ${who}`);
    const ticket = randomUUID(),
      announcement = randomUUID();
    try {
      assert.equal((await request(app).get("/v1/admin/me")).status, 401);
      assert.equal((await call("get", "/v1/admin/me", "alice")).status, 403);
      assert.equal(
        (await call("get", "/v1/admin/me", "unverified")).status,
        200,
      );
      assert.equal((await call("get", "/v1/admin/me")).status, 200);
      for (const who of ["admin", "alice", "bob"])
        assert.equal((await call("get", "/v1/profile", who)).status, 200);
      let r = await call("get", "/v1/admin/dashboard");
      assert.equal(r.status, 200, JSON.stringify(r.body));
      assert.ok(r.body.totals.users >= 3);
      assert.equal(r.body.notificationDelivery, null);
      const initialAiSuccess = r.body.totals.ai_success;
      r = await call("get", "/v1/admin/users?q=alice");
      assert.equal(r.status, 200);
      assert.ok(r.body.rows.some((r) => r.uid === alice));
      await transaction(pool, alice, async (c) => {
        assert.equal((await c.query("SELECT uid FROM profiles")).rowCount, 1);
        await assert.rejects(
          c.query("SELECT * FROM admin_audit"),
          (e) => e.code === "42501",
        );
      });
      const body = {
        id: ticket,
        subject: "Test request",
        message: "Please help with a reminder.",
      };
      assert.equal(
        (await call("post", "/v1/community/tickets", "alice").send(body))
          .status,
        200,
      );
      assert.equal(
        (await call("post", "/v1/community/tickets", "alice").send(body))
          .status,
        200,
      );
      assert.equal(
        (
          await call("post", "/v1/community/tickets", "alice").send({
            ...body,
            message: "Changed body",
          })
        ).status,
        409,
      );
      assert.equal(
        (await call("get", "/v1/community", "bob")).body.tickets.length,
        0,
      );
      r = await call("get", "/v1/admin/tickets");
      assert.equal(r.status, 200);
      assert.ok(r.body.rows.some((t) => t.id === ticket));
      assert.equal(
        (
          await call("patch", "/v1/admin/tickets/" + ticket).send({
            status: "resolved",
            reply: "This is the admin reply.",
            baseVersion: 1,
          })
        ).status,
        200,
      );
      assert.equal(
        (
          await call("patch", "/v1/admin/tickets/" + ticket).send({
            status: "open",
            reply: "Old version",
            baseVersion: 1,
          })
        ).status,
        409,
      );
      assert.equal(
        (await call("get", "/v1/community", "alice")).body.tickets[0].reply,
        "This is the admin reply.",
      );
      const sub = {
        plan: "monthly",
        expiresAt: new Date(Date.now() + 86400000).toISOString(),
        note: "Test manual grant",
        baseVersion: 0,
      };
      assert.equal(
        (await call("put", "/v1/admin/subscriptions/" + alice).send(sub))
          .status,
        200,
      );
      assert.equal(
        (await call("put", "/v1/admin/subscriptions/" + alice).send(sub))
          .status,
        409,
      );
      assert.equal(
        (await call("get", "/v1/community", "alice")).body.subscription.plan,
        "monthly",
      );
      assert.equal(
        (await call("get", "/v1/community", "bob")).body.subscription.plan,
        "free",
      );
      assert.equal(
        (
          await call("post", "/v1/admin/announcements").send({
            id: announcement,
            title: "Test notice",
            body: "Test announcement contents.",
          })
        ).status,
        200,
      );
      assert.equal(
        (await call("get", "/v1/community", "alice")).body.announcements.length,
        0,
      );
      assert.equal(
        (
          await call("patch", "/v1/admin/announcements/" + announcement).send({
            status: "published",
            baseVersion: 1,
          })
        ).status,
        200,
      );
      assert.equal(
        (await call("get", "/v1/community", "alice")).body.announcements.length,
        1,
      );
      assert.equal(
        (
          await call(
            "post",
            `/v1/community/announcements/${announcement}/read`,
            "alice",
          )
        ).status,
        200,
      );
      assert.equal(
        (
          await call(
            "post",
            `/v1/community/announcements/${announcement}/read`,
            "alice",
          )
        ).status,
        200,
      );
      assert.equal(
        (await call("get", "/v1/admin/announcements")).body.rows[0].reads,
        1,
      );
      assert.equal(
        (
          await call("patch", "/v1/admin/announcements/" + announcement).send({
            status: "withdrawn",
            baseVersion: 2,
          })
        ).status,
        200,
      );
      assert.equal(
        (await call("get", "/v1/community", "alice")).body.announcements.length,
        0,
      );
      assert.equal(
        (
          await call(
            "post",
            `/v1/community/announcements/${announcement}/read`,
            "bob",
          )
        ).status,
        404,
      );
      assert.equal(
        (
          await call("patch", "/v1/admin/users/" + alice).send({
            status: "suspended",
            reason: "Test cloud suspension",
          })
        ).status,
        200,
      );
      assert.equal((await call("get", "/v1/reminders", "alice")).status, 403);
      assert.equal((await call("get", "/v1/community", "bob")).status, 200);
      assert.equal(
        (
          await call("patch", "/v1/admin/users/" + admin).send({
            status: "suspended",
            reason: "Test self suspension",
          })
        ).status,
        400,
      );
      assert.equal(
        (
          await call("patch", "/v1/admin/users/" + alice).send({
            status: "active",
            reason: "Restore test access",
          })
        ).status,
        200,
      );
      assert.equal((await call("get", "/v1/reminders", "alice")).status, 200);
      r = await call("get", "/v1/admin/settings");
      assert.equal(r.status, 200);
      const v = r.body.version;
      const settings = {
        supportEmail: "support@example.test",
        maintenanceMessage: "Test inbox notice",
        baseVersion: v,
      };
      assert.equal(
        (await call("put", "/v1/admin/settings").send(settings)).status,
        200,
      );
      assert.equal(
        (await call("put", "/v1/admin/settings").send(settings)).status,
        409,
      );
      assert.equal(
        (await call("get", "/v1/community", "bob")).body.settings
          .maintenance_message,
        "Test inbox notice",
      );
      assert.equal(
        (
          await call("post", "/v1/suggestions", "alice").send({
            name: "Friend",
            eventType: "Birthday",
            relation: "Friend",
            language: "English",
            tone: "Warm",
            budget: "500",
            interests: "",
            variant: 0,
          })
        ).status,
        200,
      );
      assert.equal(
        (await call("get", "/v1/admin/dashboard")).body.totals.ai_success,
        initialAiSuccess + 1,
      );
      r = await call("get", "/v1/admin/export");
      assert.equal(r.status, 200);
      assert.ok(r.body.tables.profiles.some((p) => p.uid === alice));
      assert.ok(!JSON.stringify(r.body).includes("DATABASE_URL"));
      r = await call("get", "/v1/admin/logs");
      assert.equal(r.status, 200);
      assert.ok(r.body.rows.some((r) => r.action === "backup.exported"));
      await assert.rejects(
        adminTransaction(pool, admin, (c) =>
          c.query("DELETE FROM admin_audit"),
        ),
        (e) => e.code === "42501",
      );
    
      const detail=await call('get','/v1/admin/users/'+alice);assert.equal(detail.status,200);assert.equal(detail.body.profile.email,'alice@sample.invalid');
      assert.equal((await call('get','/v1/admin/system')).body.database,'connected');
      assert.equal((await call('get','/v1/admin/subscriptions?status=active')).body.rows.some(r=>r.uid===alice),true);
      const followId=randomUUID();
      assert.equal((await call('post',`/v1/community/tickets/${ticket}/messages`,'alice').send({id:followId,body:'I have a follow-up question.'})).status,200);
      assert.equal((await call('post',`/v1/community/tickets/${ticket}/messages`,'alice').send({id:followId,body:'I have a follow-up question.'})).status,200);
      assert.equal((await call('post',`/v1/community/tickets/${ticket}/messages`,'bob').send({id:randomUUID(),body:'Not my ticket'})).status,404);
      const thread=await call('get','/v1/admin/tickets/'+ticket);assert.equal(thread.status,200);assert.equal(thread.body.messages.length,2);assert.equal(thread.body.ticket.status,'open');
      assert.equal((await call('get','/v1/community','alice')).body.tickets[0].messages.length,2);
      assert.equal((await call('put','/v1/admin/announcements/'+announcement).send({title:'Edited '+prefix,body:'Edited draft text',baseVersion:3})).status,200);
      assert.equal((await call('get','/v1/admin/announcements?q='+encodeURIComponent('Edited '+prefix))).body.total,1);
      assert.ok((await call('get','/v1/admin/activity')).body.rows.some(r=>r.action==='user.registered'));
      const exported=await call('get','/v1/admin/export');assert.equal(exported.body.format,'yaadx-application-export-v2');assert.equal(exported.body.checksum.length,64);
      assert.ok((await call('get','/v1/admin/backups')).body.rows.some(r=>r.id===exported.body.id));
      await transaction(pool,alice,c=>c.query("UPDATE profiles SET email=$2 WHERE uid=$1",[alice,prefix+'@example.test']));
      assert.equal((await call('get','/v1/admin/users?q='+prefix+'%40example.test')).body.total,0);
      assert.equal((await call('get','/v1/admin/users?q='+prefix+'%40example.test&includeTest=1')).body.total,1);
      assert.equal((await call('get','/v1/admin/users/'+alice)).status,404);
      assert.equal((await call('get','/v1/admin/users/'+alice+'?includeTest=1')).status,200);
      await adminTransaction(pool,admin,async c=>{const result=await c.query("SELECT next_event_date('2000-02-29',true,'2027-02-01')::text d");assert.equal(result.rows[0].d,'2027-02-28');});
    } finally {
      await pool.end();
    }
  },
);
