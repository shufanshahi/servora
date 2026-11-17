/** Connection string for the dedicated test database (never the development one). */
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgres://servora:servora@localhost:5433/servora_test';
