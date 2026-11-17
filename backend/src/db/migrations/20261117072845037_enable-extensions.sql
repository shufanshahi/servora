-- Up Migration

-- citext: case-insensitive text, used for unique emails.
CREATE EXTENSION IF NOT EXISTS citext;
-- btree_gist: lets a GiST exclusion constraint combine equality (service_id) with
-- range overlap (time_range), which prevents double-booking at the database level.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Down Migration

DROP EXTENSION IF EXISTS btree_gist;
DROP EXTENSION IF EXISTS citext;
