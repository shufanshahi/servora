-- Up Migration

CREATE TYPE appointment_status AS ENUM ('PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED');

CREATE TABLE appointments (
  id          uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid               NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  -- A service with bookings can never be deleted; deactivate it instead.
  service_id  uuid               NOT NULL REFERENCES services (id) ON DELETE RESTRICT,
  starts_at   timestamptz        NOT NULL,
  ends_at     timestamptz        NOT NULL,
  -- Derived from the two columns above so the exclusion constraint always sees the
  -- same range the API reports. Half-open: back-to-back bookings do not overlap.
  time_range  tstzrange          GENERATED ALWAYS AS (tstzrange(starts_at, ends_at, '[)')) STORED,
  status      appointment_status NOT NULL DEFAULT 'PENDING',
  -- Price at the time of booking, so later catalogue edits never rewrite history.
  price_cents integer            NOT NULL CHECK (price_cents >= 0),
  note        text               CHECK (note IS NULL OR char_length(note) <= 500),
  created_at  timestamptz        NOT NULL DEFAULT now(),
  updated_at  timestamptz        NOT NULL DEFAULT now(),
  cancelled_at timestamptz,
  CONSTRAINT appointments_time_order_check CHECK (ends_at > starts_at),
  -- Capacity is one: a service cannot be booked twice for overlapping times, whatever
  -- the number of concurrent requests. Cancelled bookings free their slot.
  CONSTRAINT appointments_no_overlap EXCLUDE USING gist (
    service_id WITH =,
    time_range WITH &&
  ) WHERE (status <> 'CANCELLED')
);

CREATE INDEX appointments_user_start_idx ON appointments (user_id, starts_at);
CREATE INDEX appointments_starts_at_idx ON appointments (starts_at);

-- Down Migration

DROP TABLE IF EXISTS appointments;
DROP TYPE IF EXISTS appointment_status;
