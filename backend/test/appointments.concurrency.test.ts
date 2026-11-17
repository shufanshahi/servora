import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { registerUser, resetAppointments } from './support/appointments';
import { insertCatalogue, resetServices } from './support/services';
import { resetUsers } from './support/users';

const NOW = new Date('2030-05-01T08:00:00Z');
const { app, db } = buildTestApp(undefined, { clock: () => NOW });

let serviceId: string;
let tokens: string[];

const PARALLEL = 12;

beforeAll(async () => {
  await resetServices(db);
  await resetUsers(db);
  await resetAppointments(db);
  serviceId = (await insertCatalogue(db)).swedish as string;
  tokens = [];
  for (let i = 0; i < PARALLEL; i++) {
    tokens.push((await registerUser(app, `racer${i}@example.com`)).token);
  }
});
afterAll(async () => {
  await resetAppointments(db);
  await resetServices(db);
  await resetUsers(db);
  await db.close();
});

describe('concurrent bookings', () => {
  it('lets exactly one of many simultaneous requests for one slot succeed', async () => {
    const responses = await Promise.all(
      tokens.map((token) =>
        request(app)
          .post('/appointments')
          .set('Authorization', `Bearer ${token}`)
          .send({ serviceId, startsAt: '2030-05-06T10:00:00Z' }),
      ),
    );
    const statuses = responses.map((r) => r.status);
    expect(statuses.filter((s) => s === 201)).toHaveLength(1);
    expect(statuses.filter((s) => s === 409)).toHaveLength(PARALLEL - 1);
    for (const res of responses.filter((r) => r.status === 409)) {
      expect(res.body.error.code).toBe('SLOT_UNAVAILABLE');
    }
    const { rows } = await db.query('SELECT 1 FROM appointments');
    expect(rows).toHaveLength(1);
  });

  it('also holds for overlapping (not identical) slots', async () => {
    await resetAppointments(db);
    // 10:00, 10:30 and 11:00 hour-long bookings: 10:00 and 11:00 can coexist, 10:30 clashes
    // with both. At most two can win, and never an overlapping pair.
    const starts = ['10:00', '10:30', '11:00'];
    const responses = await Promise.all(
      starts.flatMap((start, i) =>
        [0, 1, 2, 3].map((j) =>
          request(app)
            .post('/appointments')
            .set('Authorization', `Bearer ${tokens[i * 4 + j]}`)
            .send({ serviceId, startsAt: `2030-05-06T${start}:00Z` }),
        ),
      ),
    );
    expect(responses.every((r) => r.status === 201 || r.status === 409)).toBe(true);
    const { rows } = await db.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM appointments a JOIN appointments b
         ON a.service_id = b.service_id AND a.id < b.id AND a.time_range && b.time_range`,
    );
    expect(rows[0]?.n).toBe(0);
  });
});
