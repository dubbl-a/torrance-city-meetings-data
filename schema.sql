
-- A view pins the types of the columns beneath it; drop it before the tables
-- are altered and rebuild it after.
DROP VIEW IF EXISTS meetings.v_vote_sources;
DROP VIEW IF EXISTS meetings.v_votes;

CREATE SCHEMA IF NOT EXISTS meetings;

-- ── bodies: the registry every other table scopes to ──────────────────────
CREATE TABLE IF NOT EXISTS meetings.bodies (
  body_slug        text PRIMARY KEY,
  name             text NOT NULL,
  body_kind        text NOT NULL,
  granicus_view_id integer,
  seat_count       integer,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz
);

-- ── members: the people the clerk's labels resolve to ─────────────────────
-- Identity only. No email, no phone, no address, no voter linkage: a reader
-- needs to know that "Councilmember Sheikh" and person 5745 are the same
-- person, and nothing else about them.
CREATE TABLE IF NOT EXISTS meetings.members (
  person_id      bigint PRIMARY KEY,
  canonical_name text   NOT NULL,
  clerk_labels   text[] NOT NULL DEFAULT '{}'
);

-- ── meetings ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meetings.meetings (
  meeting_id           bigint PRIMARY KEY,
  body_slug            text NOT NULL REFERENCES meetings.bodies(body_slug) ON DELETE NO ACTION,
  meeting_kind         text NOT NULL,
  meeting_date         date NOT NULL,
  started_at           timestamptz,
  title                text NOT NULL,
  duration_seconds     integer,
  closed_session_spans jsonb NOT NULL DEFAULT '[]'::jsonb,
  granicus_clip_id     integer,
  primegov_meeting_id  integer,
  video_url            text,
  created_at           timestamptz,
  updated_at           timestamptz
);
-- Columns the laptop grew after this table first shipped. CREATE TABLE IF NOT
-- EXISTS will not alter an existing table, so every later column arrives as
-- its own idempotent ALTER and this list only grows.
ALTER TABLE meetings.meetings ADD COLUMN IF NOT EXISTS roll_calls jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS meetings_body_date_kind_uidx
  ON meetings.meetings (body_slug, meeting_date, meeting_kind);
CREATE INDEX IF NOT EXISTS meetings_body_date_idx
  ON meetings.meetings (body_slug, meeting_date DESC);

-- ── agenda items ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meetings.agenda_items (
  agenda_item_id       bigint PRIMARY KEY,
  meeting_id           bigint  NOT NULL REFERENCES meetings.meetings(meeting_id) ON DELETE NO ACTION,
  granicus_meta_id     integer NOT NULL,
  ord                  integer NOT NULL,
  item_number          text,
  section_title        text,
  section_kind         text,
  title                text    NOT NULL,
  video_offset_seconds integer,
  -- Soft: self-referential inside a single rebuild, so a real FK would order
  -- the prune of this table against itself.
  parent_item_id       bigint,
  -- Soft: public_site.issue_master_groupings is not published.
  issue_grouping_slug  text
);
ALTER TABLE meetings.agenda_items ADD COLUMN IF NOT EXISTS end_offset_seconds integer;
ALTER TABLE meetings.agenda_items ADD COLUMN IF NOT EXISTS depth smallint;
ALTER TABLE meetings.agenda_items ADD COLUMN IF NOT EXISTS is_closed_session boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS agenda_items_meeting_meta_uidx
  ON meetings.agenda_items (meeting_id, granicus_meta_id);
CREATE INDEX IF NOT EXISTS agenda_items_meeting_ord_idx
  ON meetings.agenda_items (meeting_id, ord);

-- ── item identifiers ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meetings.item_identifiers (
  identifier_id   bigint PRIMARY KEY,
  agenda_item_id  bigint NOT NULL REFERENCES meetings.agenda_items(agenda_item_id) ON DELETE NO ACTION,
  id_type         text   NOT NULL,
  canonical_value text   NOT NULL,
  display_value   text   NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS item_identifiers_key_uidx
  ON meetings.item_identifiers (agenda_item_id, id_type, canonical_value);
CREATE INDEX IF NOT EXISTS item_identifiers_lookup_idx
  ON meetings.item_identifiers (id_type, canonical_value);

-- ── motions ───────────────────────────────────────────────────────────────
-- moved_by / seconded_by are the clerk's verbatim strings and are the
-- evidence; the *_person_id columns beside them are derived and rebuilt.
CREATE TABLE IF NOT EXISTS meetings.motions (
  motion_id             bigint PRIMARY KEY,
  meeting_id            bigint  NOT NULL REFERENCES meetings.meetings(meeting_id) ON DELETE NO ACTION,
  agenda_item_id        bigint  REFERENCES meetings.agenda_items(agenda_item_id) ON DELETE NO ACTION,
  granicus_meta_id      integer NOT NULL,
  motion_text           text    NOT NULL,
  motion_verb           text,
  motion_class          text,
  moved_by              text,
  moved_by_person_id    bigint  REFERENCES meetings.members(person_id) ON DELETE NO ACTION,
  seconded_by           text,
  seconded_by_person_id bigint  REFERENCES meetings.members(person_id) ON DELETE NO ACTION,
  outcome               text,
  video_offset_seconds  integer
);
-- The clerk's index entry that carries the OUTCOME of this motion, as opposed
-- to granicus_meta_id, which is the motion itself. Added after the table first
-- shipped, so it arrives as its own idempotent ALTER.
ALTER TABLE meetings.motions ADD COLUMN IF NOT EXISTS outcome_meta_id integer;

CREATE UNIQUE INDEX IF NOT EXISTS motions_meeting_meta_uidx
  ON meetings.motions (meeting_id, granicus_meta_id);
CREATE INDEX IF NOT EXISTS motions_item_idx
  ON meetings.motions (agenda_item_id) WHERE agenda_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS motions_class_idx
  ON meetings.motions (motion_class, motion_verb);

-- ── votes ─────────────────────────────────────────────────────────────────
-- A row means "recorded on the panel". A NULL vote_value means "recorded,
-- value not published", which is not the same as unknown and neither is the
-- same as absent; vote_value_source says where a recovered value came from.
CREATE TABLE IF NOT EXISTS meetings.votes (
  vote_id           bigint PRIMARY KEY,
  motion_id         bigint NOT NULL REFERENCES meetings.motions(motion_id) ON DELETE NO ACTION,
  member_name       text   NOT NULL,
  vote_value        text,
  vote_value_source text,
  person_id         bigint REFERENCES meetings.members(person_id) ON DELETE NO ACTION
);
CREATE UNIQUE INDEX IF NOT EXISTS votes_motion_member_uidx
  ON meetings.votes (motion_id, member_name);
CREATE INDEX IF NOT EXISTS votes_person_idx
  ON meetings.votes (person_id) WHERE person_id IS NOT NULL;

-- ── seats: the time-varying roster ────────────────────────────────────────
-- Half-open bounds with NULL meaning unbounded. A NULL valid_from means the
-- evidence window starts later than the seat did, never that the seat began
-- at an unknown date.
CREATE TABLE IF NOT EXISTS meetings.seats (
  person_id    bigint NOT NULL REFERENCES meetings.members(person_id) ON DELETE NO ACTION,
  body_slug    text   REFERENCES meetings.bodies(body_slug) ON DELETE NO ACTION,
  role         text   NOT NULL,
  jurisdiction text,
  valid_from   date,
  valid_to     date,
  source_ref   text
);
CREATE UNIQUE INDEX IF NOT EXISTS seats_key_uidx
  ON meetings.seats (person_id, body_slug, role, valid_from) NULLS NOT DISTINCT;

-- ── artifacts: the provenance ledger ──────────────────────────────────────
-- No local file-path column: it names a directory on one laptop, so it is
-- noise to every reader of this schema. The archive it points at is not
-- published either.
CREATE TABLE IF NOT EXISTS meetings.artifacts (
  artifact_id   bigint PRIMARY KEY,
  meeting_id    bigint REFERENCES meetings.meetings(meeting_id) ON DELETE NO ACTION,
  artifact_kind text        NOT NULL,
  source_url    text        NOT NULL,
  sha256        text        NOT NULL,
  byte_size     bigint,
  content_type  text,
  http_status   integer,
  fetched_at    timestamptz NOT NULL,
  -- Set when the bytes were deliberately deleted from the laptop archive while
  -- the row kept its sha256 (--prune-video). Published because without it this
  -- table keeps asserting a 7 GB artifact nobody holds any more, and a reader
  -- has no way to tell a prune from a fetch. NOT a supersede: nothing revised
  -- the artifact, and the row is still re-pullable from source_url.
  pruned_at     timestamptz,
  -- Soft: the supersession chain points inside this same table.
  superseded_by bigint
);
ALTER TABLE meetings.artifacts ADD COLUMN IF NOT EXISTS pruned_at timestamptz;
CREATE INDEX IF NOT EXISTS artifacts_meeting_idx
  ON meetings.artifacts (meeting_id);
CREATE INDEX IF NOT EXISTS artifacts_current_idx
  ON meetings.artifacts (meeting_id, artifact_kind) WHERE superseded_by IS NULL;

-- ── Row-level provenance (laptop migration 157) ───────────────────────────
-- A motion cites the index it was parsed from and the vote panel its rows
-- came from; a vote value cites the document it was read from. These arrive
-- as ALTERs after artifacts exists because they reference it, and each is a
-- single line so the test suite can match it against MEETINGS_COLUMNS.
--
-- panel_status: 'complete' when Granicus served the whole panel; 'partial'
-- when the panel came from a 500 body that stopped rendering at a recusal or
-- abstention row (the member set is incomplete, and panel_artifact_id's
-- http_status is 500); 'none' when no panel was served and any member rows
-- were named by the minutes instead.
ALTER TABLE meetings.motions ADD COLUMN IF NOT EXISTS structure_artifact_id bigint REFERENCES meetings.artifacts(artifact_id) ON DELETE NO ACTION;
ALTER TABLE meetings.motions ADD COLUMN IF NOT EXISTS panel_artifact_id bigint REFERENCES meetings.artifacts(artifact_id) ON DELETE NO ACTION;
ALTER TABLE meetings.motions ADD COLUMN IF NOT EXISTS panel_status text NOT NULL DEFAULT 'none';
ALTER TABLE meetings.votes ADD COLUMN IF NOT EXISTS source_artifact_id bigint REFERENCES meetings.artifacts(artifact_id) ON DELETE NO ACTION;
CREATE INDEX IF NOT EXISTS votes_source_artifact_idx
  ON meetings.votes (source_artifact_id) WHERE source_artifact_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS motions_panel_artifact_idx
  ON meetings.motions (panel_artifact_id) WHERE panel_artifact_id IS NOT NULL;

-- ── publish_runs: the ledger ──────────────────────────────────────────────
-- One row per applied run, written inside the publish transaction so a
-- rolled-back publish leaves no claim that it happened.
CREATE TABLE IF NOT EXISTS meetings.publish_runs (
  run_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  started_at     timestamptz NOT NULL,
  finished_at    timestamptz NOT NULL DEFAULT now(),
  mode           text        NOT NULL,
  laptop_git_sha text,
  brake_tripped  boolean     NOT NULL DEFAULT false,
  force_reason   text,
  counts         jsonb       NOT NULL DEFAULT '{}'::jsonb
);

-- ── The one view ──────────────────────────────────────────────────────────
-- Every join is LEFT: votes.person_id is null until the roster resolves a
-- clerk label, and motions.agenda_item_id is null for a motion the clerk
-- filed under no item. An INNER join would silently drop exactly the rows a
-- reader is most likely to be checking on.
--
-- member_name is the clerk's label from the vote row itself, never a value
-- reconstructed from members.clerk_labels: the vote table is unique on
-- (motion_id, member_name), so the label IS the identity of the panel row.
--
-- One view, and no summary views. A pre-aggregated count would freeze one
-- question's shape, and a reader with SQL can ask their own.
CREATE VIEW meetings.v_votes AS
SELECT b.body_slug,
       m.meeting_date,
       ai.item_number,
       ai.title,
       mo.motion_text,
       mo.motion_class,
       mo.outcome,
       v.member_name,
       mem.canonical_name,
       v.vote_value,
       v.vote_value_source,
       v.person_id,
       v.source_artifact_id,
       mo.panel_status
  FROM meetings.votes v
  LEFT JOIN meetings.motions      mo  ON mo.motion_id = v.motion_id
  LEFT JOIN meetings.agenda_items ai  ON ai.agenda_item_id = mo.agenda_item_id
  LEFT JOIN meetings.meetings     m   ON m.meeting_id = mo.meeting_id
  LEFT JOIN meetings.bodies       b   ON b.body_slug = m.body_slug
  LEFT JOIN meetings.members      mem ON mem.person_id = v.person_id;

-- ── The provenance view ───────────────────────────────────────────────────
-- One row per vote row, with the three documents behind it: the one the
-- value was read from, the panel the member list came from, and the index
-- the motion was parsed from. Every join is LEFT, so a NULL source_url beside
-- a NULL vote_value is the expected shape and a NULL beside a value would be
-- a bug the laptop CHECK constraint refuses to publish.
CREATE VIEW meetings.v_vote_sources AS
SELECT v.vote_id,
       v.motion_id,
       m.meeting_date,
       ai.item_number,
       v.member_name,
       v.vote_value,
       v.vote_value_source,
       mo.panel_status,
       src.artifact_id   AS source_artifact_id,
       src.artifact_kind AS source_kind,
       src.source_url    AS source_url,
       src.sha256        AS source_sha256,
       src.fetched_at    AS source_fetched_at,
       pan.artifact_id   AS panel_artifact_id,
       pan.source_url    AS panel_url,
       pan.sha256        AS panel_sha256,
       pan.http_status   AS panel_http_status,
       idx.artifact_id   AS structure_artifact_id,
       idx.source_url    AS structure_url,
       idx.sha256        AS structure_sha256
  FROM meetings.votes v
  LEFT JOIN meetings.motions      mo  ON mo.motion_id = v.motion_id
  LEFT JOIN meetings.agenda_items ai  ON ai.agenda_item_id = mo.agenda_item_id
  LEFT JOIN meetings.meetings     m   ON m.meeting_id = mo.meeting_id
  LEFT JOIN meetings.artifacts    src ON src.artifact_id = v.source_artifact_id
  LEFT JOIN meetings.artifacts    pan ON pan.artifact_id = mo.panel_artifact_id
  LEFT JOIN meetings.artifacts    idx ON idx.artifact_id = mo.structure_artifact_id;

-- ── Reader role ───────────────────────────────────────────────────────────
-- A login role with SELECT on this schema and nothing anywhere else. Its
-- password is NOT set here: a credential belongs in the Neon console and in
-- whatever the reader keeps it in, never in a script that prints its own
-- steps. ALTER DEFAULT PRIVILEGES is what keeps a table added next month
-- readable without a second grant run.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='meetings_reader') THEN CREATE ROLE meetings_reader LOGIN; END IF; END $$;
GRANT USAGE ON SCHEMA meetings TO meetings_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA meetings TO meetings_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA meetings GRANT SELECT ON TABLES TO meetings_reader;
-- Removes any grant made TO this role by name. It does NOT remove USAGE on
-- public, which Postgres grants to the pseudo-role PUBLIC and no per-role
-- REVOKE can take back; verified after the first DDL run. That is acceptable
-- rather than fixed here: since Postgres 15 the public schema grants PUBLIC no
-- CREATE, this project's public schema holds nothing, and revoking from PUBLIC
-- would change the database for every other role too. If anything is ever
-- created in public, it needs its own revoke.
REVOKE ALL ON SCHEMA public FROM meetings_reader;
