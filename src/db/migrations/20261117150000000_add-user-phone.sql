-- Up Migration

-- Optional contact number, kept as the user typed it (trimmed). The API validates the format.
ALTER TABLE users ADD COLUMN phone text CHECK (phone IS NULL OR char_length(phone) BETWEEN 6 AND 30);

-- Down Migration

ALTER TABLE users DROP COLUMN IF EXISTS phone;
