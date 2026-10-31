-- Forward-only correction: keep applied migration checksums unchanged.
CREATE OR REPLACE FUNCTION next_event_date(original date, yearly boolean, reference date)
RETURNS date LANGUAGE SQL IMMUTABLE AS $$
 WITH start AS (
  SELECT greatest(extract(year FROM reference)::int,extract(year FROM original)::int) y
 ), years AS (SELECT y FROM start UNION ALL SELECT y+1 FROM start),
 candidates AS (
  SELECT make_date(y,extract(month FROM original)::int,
   least(extract(day FROM original)::int,
    extract(day FROM (make_date(y,extract(month FROM original)::int,1)+interval '1 month - 1 day'))::int)) d
  FROM years
 )
 SELECT CASE WHEN yearly THEN (SELECT min(d) FROM candidates WHERE d>=reference AND d>=original) ELSE original END
$$;

-- Preserve the last pre-thread reply before subsequent follow-ups or status edits.
-- Deterministic IDs and matching-message checks prevent duplicate backfills.
INSERT INTO ticket_messages(id,ticket_id,uid,author,body,created_at)
SELECT md5('legacy-support-reply:'||t.id::text)::uuid,t.id,t.uid,'admin',t.reply,
 least(t.updated_at,coalesce((SELECT min(m.created_at) FROM ticket_messages m WHERE m.ticket_id=t.id),t.updated_at))-interval '1 microsecond'
FROM support_tickets t
WHERE length(trim(t.reply))>0
 AND NOT EXISTS(SELECT 1 FROM ticket_messages m WHERE m.ticket_id=t.id AND m.author='admin' AND m.body=t.reply)
ON CONFLICT(id) DO NOTHING;
