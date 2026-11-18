import { describe, expect, it } from 'vitest';
import {
  businessDateOf,
  generateSlots,
  type BookingRules,
} from '../src/modules/appointments/availability';

const rules: BookingRules = {
  timeZone: 'UTC',
  openTime: '09:00',
  closeTime: '17:00',
  slotIntervalMinutes: 30,
  minLeadMinutes: 60,
  horizonDays: 30,
};
const at = (iso: string) => new Date(iso);
const labels = (slots: { label: string }[]) => slots.map((s) => s.label);
const free = (slots: { label: string; available: boolean }[]) =>
  slots.filter((s) => s.available).map((s) => s.label);

// A far-away "now" so nothing is too soon unless a test wants it to be.
const earlier = at('2030-05-01T00:00:00Z');

describe('generateSlots', () => {
  it('lists the whole grid for a normal day', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 60,
      now: earlier,
      rules,
      bookedRanges: [],
    });
    expect(slots).toHaveLength(15); // 09:00 .. 16:00 every 30 min
    expect(slots[0]).toEqual({
      startsAt: '2030-05-06T09:00:00.000Z',
      endsAt: '2030-05-06T10:00:00.000Z',
      label: '09:00',
      available: true,
    });
    expect(slots.at(-1)?.label).toBe('16:00');
    expect(slots.every((s) => s.available)).toBe(true);
  });

  it('stops listing slots that would end after closing time', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 90,
      now: earlier,
      rules,
      bookedRanges: [],
    });
    expect(labels(slots).at(-1)).toBe('15:30'); // ends exactly 17:00
    expect(labels(slots)).not.toContain('16:00');
  });

  it('lists nothing when the service is longer than the opening hours', () => {
    expect(
      generateSlots({
        date: '2030-05-06',
        durationMinutes: 9 * 60,
        now: earlier,
        rules,
        bookedRanges: [],
      }),
    ).toEqual([]);
  });

  it('marks past and too-soon slots on today as unavailable', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 30,
      now: at('2030-05-06T11:10:00Z'), // lead 60 -> earliest 12:10
      rules,
      bookedRanges: [],
    });
    expect(free(slots)[0]).toBe('12:30');
    expect(slots.find((s) => s.label === '09:00')?.available).toBe(false);
    expect(slots.find((s) => s.label === '12:00')?.available).toBe(false);
  });

  it('allows a slot starting exactly at the lead-time limit', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 30,
      now: at('2030-05-06T11:00:00Z'),
      rules,
      bookedRanges: [],
    });
    expect(free(slots)[0]).toBe('12:00');
  });

  it('makes every slot of a past day unavailable', () => {
    const slots = generateSlots({
      date: '2030-05-05',
      durationMinutes: 30,
      now: at('2030-05-06T08:00:00Z'),
      rules,
      bookedRanges: [],
    });
    expect(slots.length).toBeGreaterThan(0);
    expect(free(slots)).toEqual([]);
  });

  it('makes days beyond the booking horizon unavailable', () => {
    const now = at('2030-05-01T09:00:00Z');
    const inside = generateSlots({
      date: '2030-05-31',
      durationMinutes: 30,
      now,
      rules,
      bookedRanges: [],
    });
    const outside = generateSlots({
      date: '2030-06-02',
      durationMinutes: 30,
      now,
      rules,
      bookedRanges: [],
    });
    expect(free(inside).length).toBeGreaterThan(0);
    expect(free(outside)).toEqual([]);
  });

  it('blocks every slot that overlaps an existing booking', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 60,
      now: earlier,
      rules,
      bookedRanges: [{ start: at('2030-05-06T10:00:00Z'), end: at('2030-05-06T11:00:00Z') }],
    });
    const blocked = slots.filter((s) => !s.available).map((s) => s.label);
    // 09:30 (ends 10:30), 10:00 and 10:30 (starts 10:30) overlap; 09:00 and 11:00 only touch.
    expect(blocked).toEqual(['09:30', '10:00', '10:30']);
  });

  it('treats back-to-back bookings as non-overlapping', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 30,
      now: earlier,
      rules,
      bookedRanges: [{ start: at('2030-05-06T10:00:00Z'), end: at('2030-05-06T10:30:00Z') }],
    });
    expect(slots.find((s) => s.label === '09:30')?.available).toBe(true);
    expect(slots.find((s) => s.label === '10:00')?.available).toBe(false);
    expect(slots.find((s) => s.label === '10:30')?.available).toBe(true);
  });

  it('returns UTC instants and business-zone labels for a non-UTC zone', () => {
    const slots = generateSlots({
      date: '2030-05-06',
      durationMinutes: 30,
      now: earlier,
      rules: { ...rules, timeZone: 'Asia/Karachi' }, // UTC+5, no DST
      bookedRanges: [],
    });
    expect(slots[0]?.label).toBe('09:00');
    expect(slots[0]?.startsAt).toBe('2030-05-06T04:00:00.000Z');
  });

  it('keeps wall-clock opening hours across a daylight-saving change', () => {
    const ny = { ...rules, timeZone: 'America/New_York' };
    const input = { durationMinutes: 30, now: earlier, rules: ny, bookedRanges: [] };
    const before = generateSlots({ ...input, date: '2030-03-09' }); // EST, UTC-5
    const change = generateSlots({ ...input, date: '2030-03-10' }); // clocks jump at 02:00
    expect(before[0]?.startsAt).toBe('2030-03-09T14:00:00.000Z');
    expect(change[0]?.startsAt).toBe('2030-03-10T13:00:00.000Z'); // EDT, UTC-4
    expect(labels(change)).toEqual(labels(before));
  });

  it('returns nothing for an invalid date', () => {
    expect(
      generateSlots({
        date: 'not-a-date',
        durationMinutes: 30,
        now: earlier,
        rules,
        bookedRanges: [],
      }),
    ).toEqual([]);
  });
});

describe('businessDateOf', () => {
  it('uses the business zone, not UTC, to find the calendar day', () => {
    const instant = at('2030-05-06T22:00:00Z');
    expect(businessDateOf(instant, 'UTC')).toBe('2030-05-06');
    expect(businessDateOf(instant, 'Asia/Karachi')).toBe('2030-05-07');
  });
});
