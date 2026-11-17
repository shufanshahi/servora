-- Up Migration

CREATE TABLE services (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Unique so the seed script can upsert by name and run any number of times safely.
  name             text        NOT NULL CONSTRAINT services_name_key UNIQUE
                               CHECK (char_length(name) BETWEEN 1 AND 120),
  description      text        NOT NULL CHECK (char_length(description) >= 1),
  category         text        NOT NULL CHECK (char_length(category) BETWEEN 1 AND 50),
  -- Money is stored as whole cents to avoid floating-point rounding. The API exposes
  -- a decimal `price` computed from it.
  price_cents      integer     NOT NULL CHECK (price_cents >= 0),
  duration_minutes integer     NOT NULL CHECK (duration_minutes BETWEEN 1 AND 480),
  -- Path relative to the API's public folder (for example /images/services/x.jpg).
  -- The absolute URL is built from PUBLIC_BASE_URL when a response is produced, so
  -- moving the API to another host never requires touching stored data.
  image_path       text,
  is_featured      boolean     NOT NULL DEFAULT false,
  -- Inactive services are hidden from every public endpoint but keep their history.
  is_active        boolean     NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX services_category_idx ON services (category);
CREATE INDEX services_active_idx ON services (is_active);

-- Down Migration

DROP TABLE IF EXISTS services;
