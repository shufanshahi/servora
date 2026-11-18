import type { Db } from '../../db/pool';
import { buildCountQuery, buildListQuery } from './services.query';
import type { ListServicesFilters } from './services.schemas';

export interface ServiceRecord {
  id: string;
  name: string;
  description: string;
  category: string;
  priceCents: number;
  durationMinutes: number;
  imagePath: string | null;
  isFeatured: boolean;
}

interface ServiceRow {
  id: string;
  name: string;
  description: string;
  category: string;
  price_cents: number;
  duration_minutes: number;
  image_path: string | null;
  is_featured: boolean;
}

function toRecord(row: ServiceRow): ServiceRecord {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    category: row.category,
    priceCents: row.price_cents,
    durationMinutes: row.duration_minutes,
    imagePath: row.image_path,
    isFeatured: row.is_featured,
  };
}

export class ServicesRepository {
  constructor(private readonly db: Db) {}

  /** One page of active services plus the total number that match the filters. */
  async list(filters: ListServicesFilters): Promise<{ items: ServiceRecord[]; total: number }> {
    const page = buildListQuery(filters);
    const count = buildCountQuery(filters);
    const [rows, total] = await Promise.all([
      this.db.query<ServiceRow>(page.text, page.values),
      this.db.query<{ total: number }>(count.text, count.values),
    ]);
    return { items: rows.rows.map(toRecord), total: total.rows[0]?.total ?? 0 };
  }

  /** Every active service (the catalogue is small), ordered for stable output. */
  async listActive(): Promise<ServiceRecord[]> {
    const result = await this.db.query<ServiceRow>(
      `SELECT id, name, description, category, price_cents, duration_minutes, image_path, is_featured
       FROM services WHERE is_active = true ORDER BY category, name`,
    );
    return result.rows.map(toRecord);
  }

  /** An active service by id, or null (inactive services are treated as missing). */
  async findActiveById(id: string): Promise<ServiceRecord | null> {
    const result = await this.db.query<ServiceRow>(
      `SELECT id, name, description, category, price_cents, duration_minutes, image_path, is_featured
       FROM services WHERE id = $1 AND is_active = true`,
      [id],
    );
    const row = result.rows[0];
    return row ? toRecord(row) : null;
  }
}
