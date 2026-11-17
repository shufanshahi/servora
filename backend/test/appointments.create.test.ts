import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { registerUser, resetAppointments } from './support/appointments';
import { insertCatalogue, resetServices } from './support/services';
import { resetUsers } from './support/users';

const NOW = new Date('2030-05-01T08:00:00Z');
const { app, db } = buildTestApp(undefined, { clock: () => NOW });

let ids: Record<string, string>;
let ada: { id: string; token: string };
let bob: { id: string; token: string };

beforeAll(async () => {
  await resetServices(db);
  await resetUsers(db);
  ids = await insertCatalogue(db);
  ada = await registerUser(app, 'ada@example.com');
  bob = await registerUser(app, 'bob@example.com');
});
beforeEach(() => resetAppointments(db));
afterAll(async () => {
  await resetAppointments(db);
  await resetServices(db);
  await resetUsers(db);
  await db.close();
});

const book = (token: string | null, body: Record<string, unknown>) => {
  const req = request(app).post('/appointments');
  return (token ? req.set('Authorization', `Bearer ${token}`) : req).send(body);
};

describe('POST /appointments', () => {
  it('creates a PENDING booking with end time and price snapshot', async () => {
    const res = await book(ada.token, {
      serviceId: ids.swedish,
      startsAt: '2030-05-06T10:00:00Z',
      note: '  Please use unscented oil  ',
    });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({
      status: 'PENDING',
      startsAt: '2030-05-06T10:00:00.000Z',
      endsAt: '2030-05-06T11:00:00.000Z',
      price: 65,
      note: 'Please use unscented oil',
      cancelledAt: null,
      service: { id: ids.swedish, name: 'Swedish Massage', durationMinutes: 60 },
    });
    expect(res.body.data.id).toEqual(expect.any(String));
  });

  it('keeps the booked price when the service price changes later', async () => {
    const res = await book(ada.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    await db.query('UPDATE services SET price_cents = 9900 WHERE id = $1', [ids.swedish]);
    const read = await request(app)
      .get(`/appointments/${res.body.data.id}`)
      .set('Authorization', `Bearer ${ada.token}`);
    expect(read.body.data.price).toBe(65);
    await db.query('UPDATE services SET price_cents = 6500 WHERE id = $1', [ids.swedish]);
  });

  it('accepts a start time written with an offset', async () => {
    const res = await book(ada.token, {
      serviceId: ids.manicure,
      startsAt: '2030-05-06T15:00:00+05:00', // 10:00 UTC
    });
    expect(res.status).toBe(201);
    expect(res.body.data.startsAt).toBe('2030-05-06T10:00:00.000Z');
  });

  it('rejects an overlapping booking of the same service with 409 SLOT_UNAVAILABLE', async () => {
    await book(ada.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    const res = await book(bob.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:30:00Z' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('SLOT_UNAVAILABLE');
    const { rows } = await db.query('SELECT 1 FROM appointments');
    expect(rows).toHaveLength(1);
  });

  it('allows back-to-back bookings of the same service', async () => {
    await book(ada.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    const res = await book(bob.token, { serviceId: ids.swedish, startsAt: '2030-05-06T11:00:00Z' });
    expect(res.status).toBe(201);
  });

  it('lets a different service use the same time', async () => {
    await book(ada.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    const res = await book(bob.token, { serviceId: ids.yoga, startsAt: '2030-05-06T10:00:00Z' });
    expect(res.status).toBe(201);
  });

  it('reuses the slot after the booking is cancelled', async () => {
    const first = await book(ada.token, {
      serviceId: ids.swedish,
      startsAt: '2030-05-06T10:00:00Z',
    });
    await request(app)
      .patch(`/appointments/${first.body.data.id}/cancel`)
      .set('Authorization', `Bearer ${ada.token}`);
    const res = await book(bob.token, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    expect(res.status).toBe(201);
  });

  it.each([
    ['in the past', '2030-04-30T10:00:00Z'],
    ['earlier today', '2030-05-01T07:00:00Z'],
    ['inside the minimum lead time', '2030-05-01T08:30:00Z'],
    ['beyond the booking horizon', '2030-06-10T10:00:00Z'],
    ['off the slot grid', '2030-05-06T10:15:00Z'],
    ['before opening', '2030-05-06T08:30:00Z'],
    ['running past closing', '2030-05-06T16:30:00Z'], // 60 min service
    ['with seconds off the minute', '2030-05-06T10:00:30Z'],
  ])('rejects a start time %s with 422', async (_name, startsAt) => {
    const res = await book(ada.token, { serviceId: ids.swedish, startsAt });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details[0].field).toBe('startsAt');
  });

  it('rejects a start time without a time zone, a bad time, and an overlong note', async () => {
    for (const body of [
      { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00' },
      { serviceId: ids.swedish, startsAt: 'tomorrow' },
      { serviceId: ids.swedish },
      { startsAt: '2030-05-06T10:00:00Z' },
      { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z', note: 'x'.repeat(501) },
    ]) {
      const res = await book(ada.token, body);
      expect(res.status, JSON.stringify(body)).toBe(422);
    }
  });

  it('answers 404 for unknown, malformed and inactive services', async () => {
    for (const serviceId of ['00000000-0000-4000-8000-000000000000', 'nope', ids.retired]) {
      const res = await book(ada.token, { serviceId, startsAt: '2030-05-06T10:00:00Z' });
      expect(res.status, String(serviceId)).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    }
  });

  it('requires authentication', async () => {
    const res = await book(null, { serviceId: ids.swedish, startsAt: '2030-05-06T10:00:00Z' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('ignores a userId or status supplied by the client', async () => {
    const res = await book(ada.token, {
      serviceId: ids.swedish,
      startsAt: '2030-05-06T10:00:00Z',
      userId: bob.id,
      status: 'COMPLETED',
    });
    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('PENDING');
    const { rows } = await db.query('SELECT user_id FROM appointments');
    expect(rows[0]?.user_id).toBe(ada.id);
  });
});
