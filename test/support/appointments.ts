import type { Db } from '../../src/db/pool';

export async function resetAppointments(db: Db): Promise<void> {
  await db.query('TRUNCATE appointments RESTART IDENTITY CASCADE');
}

/** Inserts a user row directly (no password flow) and returns its id. */
export async function insertUser(db: Db, email = 'fixture@example.com'): Promise<string> {
  const result = await db.query<{ id: string }>(
    `INSERT INTO users (name, email, password_hash) VALUES ('Fixture', $1, 'x') RETURNING id`,
    [email],
  );
  return (result.rows[0] as { id: string }).id;
}

export async function insertAppointment(
  db: Db,
  a: {
    userId: string;
    serviceId: string;
    startsAt: string;
    endsAt: string;
    status?: string;
    priceCents?: number;
  },
): Promise<string> {
  const result = await db.query<{ id: string }>(
    `INSERT INTO appointments (user_id, service_id, starts_at, ends_at, status, price_cents)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [a.userId, a.serviceId, a.startsAt, a.endsAt, a.status ?? 'PENDING', a.priceCents ?? 1000],
  );
  return (result.rows[0] as { id: string }).id;
}

/** Registers a user through the API and returns their id and bearer token. */
export async function registerUser(
  app: import('express').Express,
  email: string,
): Promise<{ id: string; token: string }> {
  const { default: request } = await import('supertest');
  const res = await request(app)
    .post('/auth/register')
    .send({ name: 'Test User', email, password: 'Sup3rSecret' });
  return { id: res.body.data.user.id, token: res.body.data.accessToken };
}
