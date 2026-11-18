import { DateTime } from 'luxon';

/** The business rules that decide which start times can be booked. */
export interface BookingRules {
  /** IANA zone in which opening hours and calendar days are interpreted. */
  timeZone: string;
  /** "HH:MM" wall-clock time of the first slot. */
  openTime: string;
  /** "HH:MM" wall-clock time by which a booking must have ended. */
  closeTime: string;
  slotIntervalMinutes: number;
  minLeadMinutes: number;
  horizonDays: number;
}

export interface TimeRange {
  start: Date;
  end: Date;
}

export interface Slot {
  /** Start as a UTC instant (ISO 8601). */
  startsAt: string;
  endsAt: string;
  /** Start as wall-clock "HH:mm" in the business time zone, for display. */
  label: string;
  available: boolean;
}

export interface SlotInput {
  /** Calendar day in the business time zone, "YYYY-MM-DD". */
  date: string;
  durationMinutes: number;
  now: Date;
  rules: BookingRules;
  /** Time ranges of existing non-cancelled bookings of the service. */
  bookedRanges: readonly TimeRange[];
}

function minutesOf(time: string): number {
  const [h, m] = time.split(':').map(Number) as [number, number];
  return h * 60 + m;
}

/**
 * Every start time on the day's grid, each marked available or not. A slot is unavailable
 * when it is too soon (or already past), too far ahead, or overlaps an existing booking.
 * Slots whose booking would run past closing time are not listed at all.
 *
 * Pure: the clock and the existing bookings are passed in, nothing is read from outside.
 * Grid times are wall-clock times of the business zone, so a day with a clock change keeps
 * the same opening hours.
 */
export function generateSlots(input: SlotInput): Slot[] {
  const { date, durationMinutes, now, rules, bookedRanges } = input;
  const day = DateTime.fromISO(date, { zone: rules.timeZone }).startOf('day');
  if (!day.isValid) return [];

  const earliest = now.getTime() + rules.minLeadMinutes * 60_000;
  const latest = now.getTime() + rules.horizonDays * 24 * 60 * 60_000;
  const close = minutesOf(rules.closeTime);

  const slots: Slot[] = [];
  for (
    let minute = minutesOf(rules.openTime);
    minute + durationMinutes <= close;
    minute += rules.slotIntervalMinutes
  ) {
    const start = day.set({ hour: Math.floor(minute / 60), minute: minute % 60 });
    const end = start.plus({ minutes: durationMinutes });
    const startMs = start.toMillis();
    const endMs = end.toMillis();
    const taken = bookedRanges.some(
      (range) => startMs < range.end.getTime() && endMs > range.start.getTime(),
    );
    slots.push({
      startsAt: start.toUTC().toISO() as string,
      endsAt: end.toUTC().toISO() as string,
      label: start.toFormat('HH:mm'),
      available: !taken && startMs >= earliest && startMs <= latest,
    });
  }
  return slots;
}

/** The business-zone calendar day ("YYYY-MM-DD") that an instant falls on. */
export function businessDateOf(instant: Date, timeZone: string): string {
  return DateTime.fromJSDate(instant, { zone: timeZone }).toISODate() as string;
}
