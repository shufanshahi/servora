-- Up Migration

CREATE TABLE users (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  -- citext makes the unique constraint case-insensitive: "A@x.com" and "a@x.com" collide.
  email         citext      NOT NULL CONSTRAINT users_email_key UNIQUE,
  password_hash text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Down Migration

DROP TABLE IF EXISTS users;
