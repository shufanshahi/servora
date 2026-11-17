import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { insertAppointment, insertUser, resetAppointments } from './support/appointments';
import { insertCatalogue, resetServices } from './support/services';
import { resetUsers } from './support/users';

// Fixed clock: Wednesday 1 May 2030, 08:00 UTC. Business zone is UTC by default.
const NOW = new Date('2030-05-01T08:00:00Z');
const { app, db } = buildTestApp(undefined, { clock: () => NOW });

let ids: Record<string, string>;
let userId: string;

beforeAll(async () => {
  await resetServices(db);
  await resetUsers(db);
  ids = await insertCatalogue(db);
  userId = await insertUser(db);
});
beforeEach(() => resetAppointments(db));
afterAll(async () => {
  await resetAppointments(db);
  await resetServices(db);
  await resetUsers(db);
  await db.close();
});

const availability = (id: string, date?: string) =>
  request(app).get(`/services/${id}/availability${date ? `?date=${date}` : ''}`);

const slot = (body: { data: { slots: { label: string; available: boolean }[] } }, label: string) =>
  body.data.slots.find((s) => s.label === label);

describe('GET /services/:id/availability', () => {
  it('lists the day grid for a 60 minute service, publicly', async () => {
    const res = await availability(ids.swedish as string, '2030-05-06');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toMatchObject({
      serviceId: ids.swedish,
      date: '2030-05-06',
      timeZone: 'UTC',
      durationMinutes: 60,
    });
    expect(res.body.data.slots).toHaveLength(15);
    expect(res.body.data.slots[0]).toEqual({
      startsAt: '2030-05-06T09:00:00.000Z',
      endsAt: '2030-05-06T10:00:00.000Z',
      label: '09:00',
      available: true,
    });
  });

  it('disables slots overlapping an active booking', async () => {
    await insertAppointment(db, {
      userId,
      serviceId: ids.swedish as string,
      startsAt: '2030-05-06T10:00:00Z',
      endsAt: '2030-05-06T11:00:00Z',
      status: 'CONFIRMED',
    });
    const res = await availability(ids.swedish as string, '2030-05-06');
    const blocked = res.body.data.slots
      .filter((s: { available: boolean }) => !s.available)
      .map((s: { label: string }) => s.label);
    expect(blocked).toEqual(['09:30', '10:00', '10:30']);
  });

  it('does not let another service block the slots', async () => {
    await insertAppointment(db, {
      userId,
      serviceId: ids.yoga as string,
      startsAt: '2030-05-06T10:00:00Z',
      endsAt: '2030-05-06T11:00:00Z',
    });
    const res = await availability(ids.swedish as string, '2030-05-06');
    expect(slot(res.body, '10:00')?.available).toBe(true);
  });

  it('frees the slots of a cancelled booking', async () => {
    await insertAppointment(db, {
      userId,
      serviceId: ids.swedish as string,
      startsAt: '2030-05-06T10:00:00Z',
      endsAt: '2030-05-06T11:00:00Z',
      status: 'CANCELLED',
    });
    const res = await availability(ids.swedish as string, '2030-05-06');
    expect(slot(res.body, '10:00')?.available).toBe(true);
  });

  it('marks past and too-soon slots unavailable today', async () => {
    const later = buildTestApp(undefined, { clock: () => new Date('2030-05-01T10:10:00Z') });
    try {
      const res = await request(later.app).get(
        `/services/${ids.manicure}/availability?date=2030-05-01`,
      );
      expect(res.status).toBe(200);
      expect(slot(res.body, '09:00')?.available).toBe(false); // already past
      expect(slot(res.body, '11:00')?.available).toBe(false); // inside the 60 min lead
      expect(slot(res.body, '11:30')?.available).toBe(true);
    } finally {
      await later.db.close();
    }
  });

  it('allows a slot starting exactly at the lead-time limit', async () => {
    const res = await availability(ids.manicure as string, '2030-05-01'); // now 08:00, lead 60
    expect(slot(res.body, '09:00')?.available).toBe(true);
  });

  it.each([
    ['a past date', '2030-04-30'],
    ['a date beyond the horizon', '2030-06-05'],
    ['a malformed date', '2030-5-6'],
    ['an impossible date', '2030-02-31'],
  ])('rejects %s with 422', async (_name, date) => {
    const res = await availability(ids.swedish as string, date);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details[0].field).toBe('query.date');
  });

  it('requires the date', async () => {
    const res = await availability(ids.swedish as string);
    expect(res.status).toBe(422);
  });

  it('answers 404 for unknown, malformed and inactive services', async () => {
    for (const id of ['00000000-0000-4000-8000-000000000000', 'nope', ids.retired as string]) {
      const res = await availability(id, '2030-05-06');
      expect(res.status, id).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    }
  });
});
