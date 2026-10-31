CREATE TABLE profiles (
 uid text PRIMARY KEY CHECK (length(uid) BETWEEN 1 AND 128),
 display_name text NOT NULL DEFAULT '' CHECK (length(display_name)<=120),
 email text NOT NULL DEFAULT '' CHECK (length(email)<=320),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE preferences (
 uid text PRIMARY KEY REFERENCES profiles(uid),
 alerts_enabled boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1 CHECK(version>0), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE reminders (
 uid text NOT NULL REFERENCES profiles(uid), id text NOT NULL CHECK(length(id) BETWEEN 1 AND 128),
 data jsonb NOT NULL CHECK(jsonb_typeof(data)='object'),
 version integer NOT NULL DEFAULT 1 CHECK(version>0), deleted boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(uid,id),
 CHECK(length(data->>'name') BETWEEN 1 AND 120),
 CHECK((data->>'advanceDays')::integer BETWEEN 0 AND 10),
 CHECK(data->>'time' ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
);
CREATE INDEX reminders_active_updated ON reminders(uid,updated_at) WHERE NOT deleted;
CREATE TABLE media (
 uid text NOT NULL REFERENCES profiles(uid), id uuid NOT NULL, object_key text NOT NULL UNIQUE,
 kind text NOT NULL CHECK(kind IN ('photo','voice')), content_type text NOT NULL,
 byte_size integer NOT NULL CHECK(byte_size BETWEEN 1 AND 20971520),
 ready boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(uid,id)
);
CREATE TABLE mutations (
 uid text NOT NULL REFERENCES profiles(uid), operation_id uuid NOT NULL,
 request_hash text NOT NULL, response jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(uid,operation_id)
);
-- Every table is isolated even if an API query accidentally omits the uid filter.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['profiles','preferences','reminders','media','mutations'] LOOP
  EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('CREATE POLICY owner_only ON %I USING (uid = current_setting(''app.uid'',true)) WITH CHECK (uid = current_setting(''app.uid'',true))',t);
 END LOOP;
END $$;
