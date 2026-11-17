import type { Db } from '../../src/db/pool';

export interface FixtureService {
  name: string;
  description: string;
  category: string;
  priceCents: number;
  durationMinutes: number;
  imagePath?: string | null;
  isFeatured?: boolean;
  isActive?: boolean;
}

export async function resetServices(db: Db): Promise<void> {
  await db.query('TRUNCATE services RESTART IDENTITY CASCADE');
}

/** Inserts one service and returns its id. */
export async function insertService(db: Db, service: FixtureService): Promise<string> {
  const result = await db.query<{ id: string }>(
    `INSERT INTO services
       (name, description, category, price_cents, duration_minutes, image_path, is_featured, is_active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
    [
      service.name,
      service.description,
      service.category,
      service.priceCents,
      service.durationMinutes,
      service.imagePath ?? null,
      service.isFeatured ?? false,
      service.isActive ?? true,
    ],
  );
  return (result.rows[0] as { id: string }).id;
}

/** A small, varied catalogue with known values for exact assertions. */
export const catalogue: Record<string, FixtureService> = {
  swedish: {
    name: 'Swedish Massage',
    description: 'A relaxing full-body treatment with long, flowing strokes.',
    category: 'Wellness',
    priceCents: 6500,
    durationMinutes: 60,
    imagePath: '/images/services/swedish-massage.jpg',
    isFeatured: true,
  },
  deep: {
    name: 'Deep Tissue Massage',
    description: 'Firm pressure that targets knots and chronic tension.',
    category: 'Wellness',
    priceCents: 9500,
    durationMinutes: 90,
  },
  yoga: {
    name: 'Private Yoga',
    description: 'One-to-one stretching and breathing session.',
    category: 'Wellness',
    priceCents: 5000,
    durationMinutes: 60,
    isFeatured: true,
  },
  haircut: {
    name: 'Haircut & Styling',
    description: 'A precision cut finished with a blow-dry.',
    category: 'Beauty',
    priceCents: 4000,
    durationMinutes: 45,
    isFeatured: true,
  },
  manicure: {
    name: 'Manicure',
    description: 'Shaping, cuticle care and polish.',
    category: 'Beauty',
    priceCents: 2500,
    durationMinutes: 30,
  },
  laptop: {
    name: 'Laptop Repair',
    description: 'Diagnosis and repair of hardware and software faults.',
    category: 'Tech support',
    priceCents: 4500,
    durationMinutes: 45,
  },
  promo: {
    name: 'Spring Offer',
    description: 'Save 50% on selected visits_this month.',
    category: 'Home',
    priceCents: 3000,
    durationMinutes: 30,
  },
  retired: {
    name: 'Retired Service',
    description: 'No longer offered.',
    category: 'Wellness',
    priceCents: 1000,
    durationMinutes: 30,
    isActive: false,
  },
};

/** Inserts every fixture and returns their ids, keyed like `catalogue`. */
export async function insertCatalogue(db: Db): Promise<Record<string, string>> {
  const ids: Record<string, string> = {};
  for (const [key, service] of Object.entries(catalogue)) {
    ids[key] = await insertService(db, service);
  }
  return ids;
}
