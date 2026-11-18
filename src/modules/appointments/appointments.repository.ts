import type { Db } from '../../db/pool';
import type { Scope } from './appointments.schemas';
import type { TimeRange } from './availability';

export interface AppointmentRecord {
  id: string;
  userId: string;
  startsAt: Date;
  endsAt: Date;
  status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
  priceCents: number;
  note: string | null;
  createdAt: Date;
  cancelledAt: Date | null;
  service: {
    id: string;
    name: string;
    category: string;
    durationMinutes: number;
    imagePath: string | null;
  };
}

interface Row {
  id: string;
  user_id: string;
  starts_at: Date;
  ends_at: Date;
  status: AppointmentRecord['status'];
  price_cents: number;
  note: string | null;
  created_at: Date;
  cancelled_at: Date | null;
  service_id: string;
  service_name: string;
  service_category: string;
  service_duration: number;
  service_image_path: string | null;
}

const SELECT = `
  SELECT a.id, a.user_id, a.starts_at, a.ends_at, a.status, a.price_cents, a.note,
         a.created_at, a.cancelled_at,
         s.id AS service_id, s.name AS service_name, s.category AS service_category,
         s.duration_minutes AS service_duration, s.image_path AS service_image_path
  FROM appointments a JOIN services s ON s.id = a.service_id`;

function toRecord(row: Row): AppointmentRecord {
  return {
    id: row.id,
    userId: row.user_id,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    status: row.status,
    priceCents: row.price_cents,
    note: row.note,
    createdAt: row.created_at,
    cancelledAt: row.cancelled_at,
    service: {
      id: row.service_id,
      name: row.service_name,
      category: row.service_category,
      durationMinutes: row.service_duration,
      imagePath: row.service_image_path,
    },
  };
}

export interface NewAppointment {
  userId: string;
  serviceId: string;
  startsAt: Date;
  endsAt: Date;
  priceCents: number;
  note: string | undefined;
  now: Date;
}

export class AppointmentsRepository {
  constructor(private readonly db: Db) {}

  /** Ranges of non-cancelled bookings of a service that intersect [from, to). */
  async activeRanges(serviceId: string, from: Date, to: Date): Promise<TimeRange[]> {
    const result = await this.db.query<{ starts_at: Date; ends_at: Date }>(
      `SELECT starts_at, ends_at FROM appointments
       WHERE service_id = $1 AND status <> 'CANCELLED'
         AND starts_at < $3 AND ends_at > $2
       ORDER BY starts_at`,
      [serviceId, from, to],
    );
    return result.rows.map((row) => ({ start: row.starts_at, end: row.ends_at }));
  }

  /**
   * Inserts a PENDING booking. Throws the raw 23P01 error if it overlaps an active booking
   * of the same service; the exclusion constraint is the single source of truth.
   */
  async insert(a: NewAppointment): Promise<AppointmentRecord> {
    const result = await this.db.query<{ id: string }>(
      `INSERT INTO appointments
         (user_id, service_id, starts_at, ends_at, price_cents, note, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $7) RETURNING id`,
      [a.userId, a.serviceId, a.startsAt, a.endsAt, a.priceCents, a.note ?? null, a.now],
    );
    const found = await this.findOwned((result.rows[0] as { id: string }).id, a.userId);
    return found as AppointmentRecord;
  }

  async findOwned(id: string, userId: string): Promise<AppointmentRecord | null> {
    const result = await this.db.query<Row>(`${SELECT} WHERE a.id = $1 AND a.user_id = $2`, [
      id,
      userId,
    ]);
    const row = result.rows[0];
    return row ? toRecord(row) : null;
  }

  async list(
    userId: string,
    scope: Scope | undefined,
    now: Date,
    page: number,
    limit: number,
  ): Promise<{ items: AppointmentRecord[]; total: number }> {
    let where = 'a.user_id = $1';
    const values: unknown[] = [userId];
    let order = 'a.starts_at DESC, a.id';
    if (scope === 'upcoming') {
      where += " AND a.status IN ('PENDING','CONFIRMED') AND a.starts_at >= $2";
      values.push(now);
      order = 'a.starts_at ASC, a.id';
    } else if (scope === 'previous') {
      where += " AND (a.status IN ('COMPLETED','CANCELLED') OR a.starts_at < $2)";
      values.push(now);
    }
    const [rows, count] = await Promise.all([
      this.db.query<Row>(
        `${SELECT} WHERE ${where} ORDER BY ${order} LIMIT ${limit} OFFSET ${(page - 1) * limit}`,
        values,
      ),
      this.db.query<{ total: number }>(
        `SELECT count(*)::int AS total FROM appointments a WHERE ${where}`,
        values,
      ),
    ]);
    return { items: rows.rows.map(toRecord), total: count.rows[0]?.total ?? 0 };
  }

  /** Cancels a PENDING booking of the user. Returns false when no row qualified. */
  async cancelPending(id: string, userId: string, now: Date): Promise<boolean> {
    const result = await this.db.query(
      `UPDATE appointments SET status = 'CANCELLED', cancelled_at = $3, updated_at = $3
       WHERE id = $1 AND user_id = $2 AND status = 'PENDING'`,
      [id, userId, now],
    );
    return (result.rowCount ?? 0) > 0;
  }

  /**
   * Moves bookings along their lifecycle: PENDING older than the confirmation delay become
   * CONFIRMED, and CONFIRMED ones whose end has passed become COMPLETED. Each statement only
   * matches the source status, so running it twice, or concurrently with a cancellation, is
   * harmless: CANCELLED and COMPLETED rows are never touched.
   */
  async reconcile(
    now: Date,
    confirmDelayMinutes: number,
  ): Promise<{ confirmed: number; completed: number }> {
    const confirmed = await this.db.query(
      `UPDATE appointments SET status = 'CONFIRMED', updated_at = $1
       WHERE status = 'PENDING' AND created_at <= $1::timestamptz - make_interval(mins => $2)`,
      [now, confirmDelayMinutes],
    );
    const completed = await this.db.query(
      `UPDATE appointments SET status = 'COMPLETED', updated_at = $1
       WHERE status = 'CONFIRMED' AND ends_at <= $1`,
      [now],
    );
    return { confirmed: confirmed.rowCount ?? 0, completed: completed.rowCount ?? 0 };
  }
}
