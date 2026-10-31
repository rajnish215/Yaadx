-- Additive admin tools. Separate role; mobile role never gets cross-account read.
CREATE TABLE admin_accounts (
 uid text PRIMARY KEY REFERENCES profiles(uid), status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended')),
 reason text NOT NULL DEFAULT '' CHECK(length(reason)<=500), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE subscriptions (
 uid text PRIMARY KEY REFERENCES profiles(uid), plan text NOT NULL CHECK(plan IN ('free','monthly','yearly')),
 expires_at timestamptz, note text NOT NULL DEFAULT '' CHECK(length(note)<=500), version integer NOT NULL DEFAULT 1,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE support_tickets (
 id uuid PRIMARY KEY, uid text NOT NULL REFERENCES profiles(uid), subject text NOT NULL CHECK(length(subject) BETWEEN 3 AND 120),
 message text NOT NULL CHECK(length(message) BETWEEN 3 AND 2000), status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','in_progress','resolved')),
 reply text NOT NULL DEFAULT '' CHECK(length(reply)<=4000), version integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX support_by_owner ON support_tickets(uid,created_at DESC);
CREATE TABLE announcements (
 id uuid PRIMARY KEY, title text NOT NULL CHECK(length(title) BETWEEN 3 AND 120), body text NOT NULL CHECK(length(body) BETWEEN 3 AND 2000),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','withdrawn')),
 created_by text NOT NULL,version integer NOT NULL DEFAULT 1,created_at timestamptz NOT NULL DEFAULT now(),published_at timestamptz
);
CREATE TABLE announcement_receipts (
 uid text NOT NULL REFERENCES profiles(uid), announcement_id uuid NOT NULL REFERENCES announcements(id),read_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(uid,announcement_id)
);
CREATE TABLE admin_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor text NOT NULL, action text NOT NULL, target text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ai_usage (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,uid text NOT NULL REFERENCES profiles(uid),outcome text NOT NULL CHECK(outcome IN ('success','failed','not_configured')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_usage_created ON ai_usage(created_at);
CREATE TABLE app_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),support_email text NOT NULL DEFAULT '',maintenance_message text NOT NULL DEFAULT '',
 version integer NOT NULL DEFAULT 1,updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO app_settings(singleton) VALUES(true);
DO $$ DECLARE a text:=current_schema()||'_admin'; u text:=current_schema()||'_api'; t text; BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=a) THEN EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOBYPASSRLS',a); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=u) THEN EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOBYPASSRLS',u); END IF;
 EXECUTE format('GRANT %I TO CURRENT_USER',a);
 EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I',current_schema(),a);
 FOREACH t IN ARRAY ARRAY['profiles','preferences','reminders','media'] LOOP
  EXECUTE format('GRANT SELECT ON %I TO %I',t,a);
  EXECUTE format('CREATE POLICY admin_read ON %I FOR SELECT TO %I USING(true)',t,a);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['admin_accounts','subscriptions','support_tickets','announcements','announcement_receipts','admin_audit','ai_usage','app_settings'] LOOP
  EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('CREATE POLICY admin_access ON %I TO %I USING(true) WITH CHECK(true)',t,a);
  EXECUTE format('GRANT SELECT ON %I TO %I',t,a);
 END LOOP;
 EXECUTE format('GRANT INSERT,UPDATE,DELETE ON admin_accounts,subscriptions,support_tickets,announcements,app_settings TO %I',a);
 EXECUTE format('GRANT INSERT ON admin_audit TO %I',a);
 EXECUTE format('GRANT USAGE ON SEQUENCE admin_audit_id_seq TO %I',a);
 FOREACH t IN ARRAY ARRAY['admin_accounts','subscriptions','support_tickets','announcement_receipts','ai_usage'] LOOP
  EXECUTE format('CREATE POLICY owner_only ON %I TO %I USING(uid=current_setting(''app.uid'',true)) WITH CHECK(uid=current_setting(''app.uid'',true))',t,u);
 END LOOP;
 EXECUTE format('GRANT SELECT ON admin_accounts,subscriptions,support_tickets,announcement_receipts,app_settings,announcements TO %I',u);
 EXECUTE format('GRANT INSERT ON support_tickets,announcement_receipts,ai_usage TO %I',u);
 EXECUTE format('GRANT USAGE ON SEQUENCE ai_usage_id_seq TO %I',u);
 EXECUTE format('CREATE POLICY published_read ON announcements FOR SELECT TO %I USING(status=''published'')',u);
 EXECUTE format('CREATE POLICY settings_read ON app_settings FOR SELECT TO %I USING(true)',u);
END $$;
