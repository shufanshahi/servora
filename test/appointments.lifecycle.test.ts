import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { insertAppointment, registerUser, resetAppointments } from './support/appointments';
import { AppointmentsRepository } from '../src/modules/appointments/appointments.repository';
import { startStatusReconciler } from '../src/modules/appointments/status-reconciler';
import { insertCatalogue, resetServices } from './support/services';
import { resetUsers } from './support/users';

let now = new Date('2030-05-06T08:00:00Z');
const { app, db } = buildTestApp(undefined, {
  clock: () => now,
  env: { CONFIRM_DELAY_MINUTES: '2' },
});

let ids: Record<string, string>;
let ada: { id: string; token: string };

beforeAll(async () => {
  await resetServices(db);
  await resetUsers(db);
  ids = await insertCatalogue(db);
  ada = await registerUser(app, 'ada@example.com');
});
beforeEach(async () => {
  now = new Date('2030-05-06T08:00:00Z');
  await resetAppointments(db);
});
afterAll(async () => {
  await resetAppointments(db);
  await resetServices(db);
  await resetUsers(db);
  await db.close();
});

const read = (id: string) =>
  request(app).get(`/appointments/${id}`).set('Authorization', `Bearer ${ada.token}`);

/** A booking created at 08:00 for 10:00-11:00. */
async function seedPending(status = 'PENDING', serviceKey = 'swedish') {
  const id = await insertAppointment(db, {
    userId: ada.id,
    serviceId: ids[serviceKey] as string,
    startsAt: '2030-05-06T10:00:00Z',
    endsAt: '2030-05-06T11:00:00Z',
    status,
  });
  await db.query('UPDATE appointments SET created_at = $2 WHERE id = $1', [id, now]);
  return id;
}

async function statusOf(id: string): Promise<string> {
  const { rows } = await db.query<{ status: string }>(
    'SELECT status FROM appointments WHERE id = $1',
    [id],
  );
  return rows[0]?.status as string;
}

describe('status lifecycle', () => {
  it('stays PENDING until the confirmation delay has passed', async () => {
    const id = await seedPending();
    now = new Date('2030-05-06T08:01:59Z');
    expect((await read(id)).body.data.status).toBe('PENDING');
  });

  it('becomes CONFIRMED once the delay has passed, seen on the next read', async () => {
    const id = await seedPending();
    now = new Date('2030-05-06T08:02:00Z');
    expect((await read(id)).body.data.status).toBe('CONFIRMED');
    expect(await statusOf(id)).toBe('CONFIRMED');
  });

  it('becomes COMPLETED once the end time has passed', async () => {
    const id = await seedPending('CONFIRMED');
    now = new Date('2030-05-06T10:59:59Z');
    expect((await read(id)).body.data.status).toBe('CONFIRMED');
    now = new Date('2030-05-06T11:00:00Z');
    expect((await read(id)).body.data.status).toBe('COMPLETED');
  });

  it('progresses through every stage when a long time has passed', async () => {
    const id = await seedPending();
    now = new Date('2030-05-07T00:00:00Z');
    expect((await read(id)).body.data.status).toBe('COMPLETED');
  });

  it('reconciles before listing too', async () => {
    await seedPending();
    now = new Date('2030-05-06T09:00:00Z');
    const res = await request(app).get('/appointments').set('Authorization', `Bearer ${ada.token}`);
    expect(res.body.data[0].status).toBe('CONFIRMED');
  });

  it('never changes CANCELLED rows', async () => {
    const id = await seedPending('CANCELLED');
    now = new Date('2030-06-01T00:00:00Z');
    expect((await read(id)).body.data.status).toBe('CANCELLED');
  });

  it('never changes COMPLETED rows, nor reopens them', async () => {
    const id = await seedPending('COMPLETED');
    now = new Date('2030-06-01T00:00:00Z');
    const res = await read(id);
    expect(res.body.data.status).toBe('COMPLETED');
    const cancel = await request(app)
      .patch(`/appointments/${id}/cancel`)
      .set('Authorization', `Bearer ${ada.token}`);
    expect(cancel.status).toBe(409);
  });

  it('is idempotent: repeated runs change nothing the second time', async () => {
    const id = await seedPending();
    now = new Date('2030-05-06T08:05:00Z');
    const repository = new AppointmentsRepository(db);
    expect(await repository.reconcile(now, 2)).toEqual({ confirmed: 1, completed: 0 });
    expect(await repository.reconcile(now, 2)).toEqual({ confirmed: 0, completed: 0 });
    expect(await statusOf(id)).toBe('CONFIRMED');
  });

  it('cannot cancel once the booking has been confirmed', async () => {
    const id = await seedPending();
    now = new Date('2030-05-06T08:03:00Z');
    await read(id); // triggers confirmation
    const res = await request(app)
      .patch(`/appointments/${id}/cancel`)
      .set('Authorization', `Bearer ${ada.token}`);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('INVALID_STATUS_TRANSITION');
  });
});

describe('startStatusReconciler', () => {
  it('advances statuses on its own timer, and stops when asked', async () => {
    const id = await seedPending();
    now = new Date('2030-05-06T08:10:00Z');
    const stop = startStatusReconciler(
      db,
      { CONFIRM_DELAY_MINUTES: 2 },
      {
        intervalMs: 20,
        clock: () => now,
      },
    );
    try {
      await expect.poll(() => statusOf(id), { timeout: 2000, interval: 20 }).toBe('CONFIRMED');
    } finally {
      stop();
    }
    const other = await seedPending('PENDING', 'yoga');
    await new Promise((resolve) => setTimeout(resolve, 100));
    expect(await statusOf(other)).toBe('PENDING'); // timer stopped
  });
});
