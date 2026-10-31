-- Read-only scope views: keep reserved-domain test accounts visible on demand,
-- without deleting or modifying any user records.
CREATE VIEW admin_profiles WITH (security_invoker=true) AS
 SELECT p.*, (lower(email) LIKE '%@example.test') AS is_test FROM profiles p
 WHERE current_setting('app.include_test',true)='true' OR lower(email) NOT LIKE '%@example.test';
DO $$ DECLARE t text; v text; BEGIN
 FOREACH t IN ARRAY ARRAY['reminders','subscriptions','support_tickets','announcement_receipts','ai_usage','admin_accounts','media'] LOOP
  v:='scoped_'||t;
  EXECUTE format('CREATE VIEW %I WITH (security_invoker=true) AS SELECT t.* FROM %I t WHERE EXISTS(SELECT 1 FROM admin_profiles p WHERE p.uid=t.uid)',v,t);
  EXECUTE format('GRANT SELECT ON %I TO %I',v,current_schema()||'_admin');
 END LOOP;
 EXECUTE format('GRANT SELECT ON admin_profiles TO %I',current_schema()||'_admin');
END $$;
CREATE FUNCTION next_event_date(original date, yearly boolean, reference date) RETURNS date LANGUAGE SQL IMMUTABLE AS $$
 WITH years AS (SELECT extract(year FROM reference)::int y UNION ALL SELECT extract(year FROM reference)::int+1),
 candidates AS (SELECT make_date(y,extract(month FROM original)::int,least(extract(day FROM original)::int,extract(day FROM (make_date(y,extract(month FROM original)::int,1)+interval '1 month - 1 day'))::int)) d FROM years)
 SELECT CASE WHEN yearly THEN (SELECT min(d) FROM candidates WHERE d>=reference) ELSE original END
$$;
CREATE TABLE ticket_messages (
 id uuid PRIMARY KEY, ticket_id uuid NOT NULL REFERENCES support_tickets(id), uid text NOT NULL REFERENCES profiles(uid),
 author text NOT NULL CHECK(author IN ('user','admin')), body text NOT NULL CHECK(length(body) BETWEEN 1 AND 4000),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ticket_messages_thread ON ticket_messages(ticket_id,created_at);
CREATE TABLE backup_exports (
 id uuid PRIMARY KEY, actor text NOT NULL, record_count integer NOT NULL, checksum text NOT NULL,
 include_test boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE backup_exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE backup_exports FORCE ROW LEVEL SECURITY;
DO $$ DECLARE a text:=current_schema()||'_admin'; u text:=current_schema()||'_api'; BEGIN
 EXECUTE format('CREATE POLICY admin_all ON ticket_messages TO %I USING(true) WITH CHECK(true)',a);
 EXECUTE format('CREATE POLICY owner_read ON ticket_messages FOR SELECT TO %I USING(uid=current_setting(''app.uid'',true))',u);
 EXECUTE format('CREATE POLICY owner_insert ON ticket_messages FOR INSERT TO %I WITH CHECK(uid=current_setting(''app.uid'',true) AND author=''user'' AND EXISTS(SELECT 1 FROM support_tickets t WHERE t.id=ticket_id AND t.uid=current_setting(''app.uid'',true)))',u);
 EXECUTE format('GRANT SELECT,INSERT ON ticket_messages TO %I,%I',a,u);
 EXECUTE format('GRANT UPDATE(status,version,updated_at) ON support_tickets TO %I',u);
 EXECUTE format('CREATE POLICY admin_all ON backup_exports TO %I USING(true) WITH CHECK(true)',a);
 EXECUTE format('GRANT SELECT,INSERT ON backup_exports TO %I',a);
END $$;
