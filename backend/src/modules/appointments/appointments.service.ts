import { DateTime } from 'luxon';
import type { Config } from '../../config';
import { conflict, ERROR_CODES, notFound, validationError } from '../../http/errors';
import { registerPgErrorMapper } from '../../http/middleware/error-handler';
import type { PageMeta } from '../../http/response';
import type { ServicesRepository } from '../services/services.repository';
import type { AppointmentRecord, AppointmentsRepository } from './appointments.repository';
import type { CreateAppointmentInput, ListAppointmentsFilters } from './appointments.schemas';
import { businessDateOf, generateSlots, type BookingRules, type Slot } from './availability';

// Two concurrent bookings of one slot: the database rejects the loser with an exclusion
// violation, and this is what the client sees.
registerPgErrorMapper('23P01', () =>
  conflict(ERROR_CODES.SLOT_UNAVAILABLE, 'That time is no longer available'),
);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface AvailabilityResult {
  serviceId: string;
  /** Calendar day in the business time zone. */
  date: string;
  timeZone: string;
  durationMinutes: number;
  slots: Slot[];
}

/** The appointment shape clients receive. */
export interface PublicAppointment {
  id: string;
  service: {
    id: string;
    name: string;
    category: string;
    durationMinutes: number;
    imageUrl: string | null;
  };
  startsAt: string;
  endsAt: string;
  status: AppointmentRecord['status'];
  /** Decimal price that applied when the booking was made. */
  price: number;
  note: string | null;
  createdAt: string;
  cancelledAt: string | null;
}

type BookingConfig = Pick<
  Config,
  | 'BUSINESS_TZ'
  | 'BOOKING_OPEN_TIME'
  | 'BOOKING_CLOSE_TIME'
  | 'SLOT_INTERVAL_MINUTES'
  | 'MIN_LEAD_MINUTES'
  | 'BOOKING_HORIZON_DAYS'
  | 'CONFIRM_DELAY_MINUTES'
  | 'PUBLIC_BASE_URL'
>;

export class AppointmentsService {
  private readonly rules: BookingRules;
  private readonly baseUrl: string;
  private readonly confirmDelayMinutes: number;

  constructor(
    config: BookingConfig,
    private readonly clock: () => Date,
    private readonly services: ServicesRepository,
    private readonly appointments: AppointmentsRepository,
  ) {
    this.confirmDelayMinutes = config.CONFIRM_DELAY_MINUTES;
    this.baseUrl = config.PUBLIC_BASE_URL.replace(/\/+$/, '');
    this.rules = {
      timeZone: config.BUSINESS_TZ,
      openTime: config.BOOKING_OPEN_TIME,
      closeTime: config.BOOKING_CLOSE_TIME,
      slotIntervalMinutes: config.SLOT_INTERVAL_MINUTES,
      minLeadMinutes: config.MIN_LEAD_MINUTES,
      horizonDays: config.BOOKING_HORIZON_DAYS,
    };
  }

  async availability(serviceId: string, date: string): Promise<AvailabilityResult> {
    if (!UUID.test(serviceId)) throw notFound('Service not found');
    const service = await this.services.findActiveById(serviceId);
    if (!service) throw notFound('Service not found');

    const now = this.clock();
    const today = businessDateOf(now, this.rules.timeZone);
    const lastDay = businessDateOf(
      new Date(now.getTime() + this.rules.horizonDays * 24 * 60 * 60_000),
      this.rules.timeZone,
    );
    if (date < today || date > lastDay) {
      throw validationError([
        { field: 'query.date', message: `date must be between ${today} and ${lastDay}` },
      ]);
    }

    const dayStart = DateTime.fromISO(date, { zone: this.rules.timeZone }).startOf('day');
    const bookedRanges = await this.appointments.activeRanges(
      serviceId,
      dayStart.toJSDate(),
      dayStart.plus({ days: 1 }).toJSDate(),
    );
    return {
      serviceId,
      date,
      timeZone: this.rules.timeZone,
      durationMinutes: service.durationMinutes,
      slots: generateSlots({
        date,
        durationMinutes: service.durationMinutes,
        now,
        rules: this.rules,
        bookedRanges,
      }),
    };
  }

  /** Applies the automatic PENDING to CONFIRMED to COMPLETED progression. Idempotent. */
  reconcileStatuses(): Promise<{ confirmed: number; completed: number }> {
    return this.appointments.reconcile(this.clock(), this.confirmDelayMinutes);
  }

  async create(userId: string, input: CreateAppointmentInput): Promise<PublicAppointment> {
    if (!UUID.test(input.serviceId)) throw notFound('Service not found');
    const service = await this.services.findActiveById(input.serviceId);
    if (!service) throw notFound('Service not found');

    const now = this.clock();
    const startsAt = new Date(input.startsAt);
    const fail = (message: string) => validationError([{ field: 'startsAt', message }]);
    if (startsAt.getTime() < now.getTime()) throw fail('startsAt is in the past');

    // The day's grid, ignoring other bookings, tells us whether the start time is a real
    // slot (on the grid, inside opening hours, finishing before closing).
    const slot = generateSlots({
      date: businessDateOf(startsAt, this.rules.timeZone),
      durationMinutes: service.durationMinutes,
      now,
      rules: this.rules,
      bookedRanges: [],
    }).find((candidate) => new Date(candidate.startsAt).getTime() === startsAt.getTime());
    if (!slot) {
      throw fail(
        `startsAt must be a slot start between ${this.rules.openTime} and ${this.rules.closeTime} ` +
          `(${this.rules.timeZone}) on a ${this.rules.slotIntervalMinutes} minute grid, ending by closing time`,
      );
    }
    if (!slot.available) {
      throw fail(
        `startsAt must be at least ${this.rules.minLeadMinutes} minutes from now and within ` +
          `${this.rules.horizonDays} days`,
      );
    }

    const record = await this.appointments.insert({
      userId,
      serviceId: service.id,
      startsAt,
      endsAt: new Date(slot.endsAt),
      priceCents: service.priceCents,
      note: input.note,
      now,
    });
    return this.toPublic(record);
  }

  async list(
    userId: string,
    filters: ListAppointmentsFilters,
  ): Promise<{ items: PublicAppointment[]; meta: PageMeta }> {
    await this.reconcileStatuses();
    const { items, total } = await this.appointments.list(
      userId,
      filters.scope,
      this.clock(),
      filters.page,
      filters.limit,
    );
    return {
      items: items.map((item) => this.toPublic(item)),
      meta: { page: filters.page, limit: filters.limit, total },
    };
  }

  async get(userId: string, id: string): Promise<PublicAppointment> {
    if (!UUID.test(id)) throw notFound('Appointment not found');
    await this.reconcileStatuses();
    const record = await this.appointments.findOwned(id, userId);
    if (!record) throw notFound('Appointment not found');
    return this.toPublic(record);
  }

  async cancel(userId: string, id: string): Promise<PublicAppointment> {
    if (!UUID.test(id)) throw notFound('Appointment not found');
    // One conditional UPDATE: it cannot race with the automatic confirmation.
    const changed = await this.appointments.cancelPending(id, userId, this.clock());
    const record = await this.appointments.findOwned(id, userId);
    if (!record) throw notFound('Appointment not found');
    if (!changed) {
      throw conflict(
        ERROR_CODES.INVALID_STATUS_TRANSITION,
        `A ${record.status.toLowerCase()} appointment cannot be cancelled; only pending ones can`,
      );
    }
    return this.toPublic(record);
  }

  private toPublic(record: AppointmentRecord): PublicAppointment {
    return {
      id: record.id,
      service: {
        id: record.service.id,
        name: record.service.name,
        category: record.service.category,
        durationMinutes: record.service.durationMinutes,
        imageUrl: record.service.imagePath ? `${this.baseUrl}${record.service.imagePath}` : null,
      },
      startsAt: record.startsAt.toISOString(),
      endsAt: record.endsAt.toISOString(),
      status: record.status,
      price: Number((record.priceCents / 100).toFixed(2)),
      note: record.note,
      createdAt: record.createdAt.toISOString(),
      cancelledAt: record.cancelledAt ? record.cancelledAt.toISOString() : null,
    };
  }
}
