import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { insertAppointment, registerUser, resetAppointments } from './support/appointments';
import { insertCatalogue, resetServices } from './support/services';
import { resetUsers } from './support/users';

// Wednesday 1 May 2030, 12:00 UTC.
const NOW = new Date('2030-05-01T12:00:00Z');
const { app, db } = buildTestApp(undefined, {
  clock: () => NOW,
  env: { PUBLIC_BASE_URL: 'https://api.example.test' },
});

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

const as = (user: { token: string }, method: 'get' | 'patch', path: string) =>
  request(app)[method](path).set('Authorization', `Bearer ${user.token}`);

async function seed(
  user: { id: string },
  serviceKey: string,
  day: string,
  hour: string,
  status = 'PENDING',
) {
  const id = await insertAppointment(db, {
    userId: user.id,
    serviceId: ids[serviceKey] as string,
    startsAt: `${day}T${hour}:00:00Z`,
    endsAt: `${day}T${String(Number(hour) + 1).padStart(2, '0')}:00:00Z`,
    status,
    priceCents: 6500,
  });
  // Created "now" on the injected clock, so the automatic confirmation delay has not elapsed.
  await db.query('UPDATE appointments SET created_at = $2 WHERE id = $1', [id, NOW]);
  return id;
}

describe('GET /appointments', () => {
  it('returns 200 with an empty list when the user has none', async () => {
    const res = await as(ada, 'get', '/appointments');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: [], meta: { page: 1, limit: 20, total: 0 } });
  });

  it('requires authentication', async () => {
    const res = await request(app).get('/appointments');
    expect(res.status).toBe(401);
  });

  it("never includes another user's appointments", async () => {
    await seed(ada, 'swedish', '2030-05-06', '10');
    await seed(bob, 'yoga', '2030-05-06', '10');
    const mine = await as(ada, 'get', '/appointments');
    const theirs = await as(bob, 'get', '/appointments');
    expect(mine.body.data).toHaveLength(1);
    expect(mine.body.data[0].service.name).toBe('Swedish Massage');
    expect(theirs.body.data).toHaveLength(1);
    expect(theirs.body.data[0].service.name).toBe('Private Yoga');
  });

  it('includes a service summary with an absolute image URL', async () => {
    await seed(ada, 'swedish', '2030-05-06', '10');
    const res = await as(ada, 'get', '/appointments');
    expect(res.body.data[0]).toMatchObject({
      status: 'PENDING',
      price: 65,
      startsAt: '2030-05-06T10:00:00.000Z',
      service: {
        id: ids.swedish,
        name: 'Swedish Massage',
        category: 'Wellness',
        durationMinutes: 60,
        imageUrl: 'https://api.example.test/images/services/swedish-massage.jpg',
      },
    });
  });

  describe('scopes', () => {
    beforeEach(async () => {
      await seed(ada, 'swedish', '2030-05-08', '10'); // future pending
      await seed(ada, 'yoga', '2030-05-06', '10', 'CONFIRMED'); // future confirmed
      await seed(ada, 'deep', '2030-05-10', '10', 'CANCELLED'); // future cancelled
      await seed(ada, 'manicure', '2030-04-20', '10', 'COMPLETED'); // past completed
      await seed(ada, 'haircut', '2030-05-01', '09', 'CONFIRMED'); // started earlier today
    });

    const names = (res: request.Response) =>
      res.body.data.map((a: { service: { name: string } }) => a.service.name);

    it('upcoming: non-cancelled, starting now or later, soonest first', async () => {
      const res = await as(ada, 'get', '/appointments?scope=upcoming');
      expect(names(res)).toEqual(['Private Yoga', 'Swedish Massage']);
      expect(res.body.meta.total).toBe(2);
    });

    it('previous: completed, cancelled and past ones, newest first', async () => {
      const res = await as(ada, 'get', '/appointments?scope=previous');
      expect(names(res)).toEqual(['Deep Tissue Massage', 'Haircut & Styling', 'Manicure']);
    });

    it('without a scope returns everything, newest start first', async () => {
      const res = await as(ada, 'get', '/appointments');
      expect(res.body.meta.total).toBe(5);
      const starts: string[] = res.body.data.map((a: { startsAt: string }) => a.startsAt);
      expect(starts).toEqual([...starts].sort().reverse());
    });

    it('rejects an unknown scope with 422', async () => {
      const res = await as(ada, 'get', '/appointments?scope=soon');
      expect(res.status).toBe(422);
    });

    it('paginates and reports the total', async () => {
      const first = await as(ada, 'get', '/appointments?limit=2&page=1');
      const last = await as(ada, 'get', '/appointments?limit=2&page=3');
      expect(first.body.data).toHaveLength(2);
      expect(last.body.data).toHaveLength(1);
      expect(first.body.meta).toEqual({ page: 1, limit: 2, total: 5 });
    });
  });
});

describe('GET /appointments/:id', () => {
  it('returns the full record to its owner', async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    const res = await as(ada, 'get', `/appointments/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id, status: 'PENDING', price: 65, note: null });
  });

  it('answers 404 for another user, an unknown id and a malformed id', async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    for (const path of [
      `/appointments/${id}`, // as Bob below
      '/appointments/00000000-0000-4000-8000-000000000000',
      '/appointments/nope',
    ]) {
      const res = await as(bob, 'get', path);
      expect(res.status, path).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    }
  });
});

describe('PATCH /appointments/:id/cancel', () => {
  it('cancels a pending appointment and records the time', async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    const res = await as(ada, 'patch', `/appointments/${id}/cancel`);
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('CANCELLED');
    expect(res.body.data.cancelledAt).toBe(NOW.toISOString());
    const { rows } = await db.query('SELECT status, cancelled_at FROM appointments');
    expect(rows[0]?.status).toBe('CANCELLED');
  });

  it.each(['CONFIRMED', 'COMPLETED', 'CANCELLED'])(
    'refuses to cancel a %s appointment with 409 and leaves it unchanged',
    async (status) => {
      const id = await seed(ada, 'swedish', '2030-05-06', '10', status);
      const res = await as(ada, 'patch', `/appointments/${id}/cancel`);
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('INVALID_STATUS_TRANSITION');
      const { rows } = await db.query('SELECT status, cancelled_at FROM appointments');
      expect(rows[0]?.status).toBe(status);
      expect(rows[0]?.cancelled_at).toBeNull();
    },
  );

  it("answers 404 for another user's booking and changes nothing", async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    const res = await as(bob, 'patch', `/appointments/${id}/cancel`);
    expect(res.status).toBe(404);
    const { rows } = await db.query('SELECT status FROM appointments');
    expect(rows[0]?.status).toBe('PENDING');
  });

  it('answers 404 for unknown and malformed ids', async () => {
    for (const id of ['00000000-0000-4000-8000-000000000000', 'nope']) {
      expect((await as(ada, 'patch', `/appointments/${id}/cancel`)).status).toBe(404);
    }
  });

  it('frees the slot for availability afterwards', async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    const before = await request(app).get(`/services/${ids.swedish}/availability?date=2030-05-06`);
    expect(
      before.body.data.slots.find((s: { label: string }) => s.label === '10:00').available,
    ).toBe(false);
    await as(ada, 'patch', `/appointments/${id}/cancel`);
    const after = await request(app).get(`/services/${ids.swedish}/availability?date=2030-05-06`);
    expect(
      after.body.data.slots.find((s: { label: string }) => s.label === '10:00').available,
    ).toBe(true);
  });

  it('requires authentication', async () => {
    const id = await seed(ada, 'swedish', '2030-05-06', '10');
    expect((await request(app).patch(`/appointments/${id}/cancel`)).status).toBe(401);
  });
});
