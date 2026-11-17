import type { Db } from './pool';

export interface ServiceSeed {
  name: string;
  description: string;
  category: string;
  priceCents: number;
  durationMinutes: number;
  /** File name (without extension) of the image in public/images/services. */
  image: string;
  isFeatured?: boolean;
}

/**
 * The demo catalogue: ten services in four categories with a spread of prices and the
 * durations 30, 45, 60 and 90 minutes, so search, filters and the booking slot grid all
 * have something interesting to show.
 */
export const SERVICE_SEEDS: readonly ServiceSeed[] = [
  {
    name: 'Swedish Massage',
    description:
      'A relaxing full-body massage using long, flowing strokes to ease muscle tension, improve circulation and calm the mind. Suitable for first-time clients.',
    category: 'Wellness',
    priceCents: 6500,
    durationMinutes: 60,
    image: 'swedish-massage',
    isFeatured: true,
  },
  {
    name: 'Deep Tissue Massage',
    description:
      'Firm, focused pressure that works into the deeper layers of muscle to release chronic knots and tension in the back, neck and shoulders.',
    category: 'Wellness',
    priceCents: 9500,
    durationMinutes: 90,
    image: 'deep-tissue-massage',
  },
  {
    name: 'Private Yoga Session',
    description:
      'One-to-one yoga tailored to your level and goals, covering mobility, breathing and relaxation. Mats and props are provided.',
    category: 'Wellness',
    priceCents: 5000,
    durationMinutes: 60,
    image: 'private-yoga',
    isFeatured: true,
  },
  {
    name: 'Haircut & Styling',
    description:
      'A short consultation, a precision cut and a blow-dry, styled to suit your face shape and your daily routine.',
    category: 'Beauty',
    priceCents: 4000,
    durationMinutes: 45,
    image: 'haircut-styling',
    isFeatured: true,
  },
  {
    name: 'Manicure',
    description:
      'Nail shaping, cuticle care, a hand massage and your choice of polish for a neat, long-lasting finish.',
    category: 'Beauty',
    priceCents: 2500,
    durationMinutes: 30,
    image: 'manicure',
  },
  {
    name: 'Facial Treatment',
    description:
      'A deep-cleansing facial with gentle exfoliation, a hydrating mask and a cooling finish that leaves skin fresh and glowing.',
    category: 'Beauty',
    priceCents: 7000,
    durationMinutes: 60,
    image: 'facial-treatment',
  },
  {
    name: 'Home Cleaning',
    description:
      'A thorough clean of the kitchen, bathrooms, living areas and floors by a trained cleaner. Supplies and equipment are included.',
    category: 'Home',
    priceCents: 8000,
    durationMinutes: 90,
    image: 'home-cleaning',
    isFeatured: true,
  },
  {
    name: 'Garden & Lawn Care',
    description:
      'Lawn mowing, edging and a tidy-up of beds and borders to keep your garden looking its best all season.',
    category: 'Home',
    priceCents: 5500,
    durationMinutes: 60,
    image: 'garden-care',
  },
  {
    name: 'Laptop Diagnostics & Repair',
    description:
      'We diagnose slow, noisy or faulty laptops, clear out dust and malware, and fix common hardware and software problems.',
    category: 'Tech support',
    priceCents: 4500,
    durationMinutes: 45,
    image: 'laptop-repair',
  },
  {
    name: 'Phone Screen Repair',
    description:
      'Same-visit replacement of cracked phone screens using quality parts, with a short warranty on the repair.',
    category: 'Tech support',
    priceCents: 6000,
    durationMinutes: 30,
    image: 'phone-screen-repair',
  },
];

/**
 * Inserts the demo catalogue, or updates it in place when it already exists. Matching
 * is by name, so running it repeatedly never creates duplicates. Returns how many
 * services were written.
 */
export async function seedServices(db: Db): Promise<number> {
  for (const service of SERVICE_SEEDS) {
    await db.query(
      `INSERT INTO services
         (name, description, category, price_cents, duration_minutes, image_path, is_featured, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, true)
       ON CONFLICT (name) DO UPDATE SET
         description = EXCLUDED.description,
         category = EXCLUDED.category,
         price_cents = EXCLUDED.price_cents,
         duration_minutes = EXCLUDED.duration_minutes,
         image_path = EXCLUDED.image_path,
         is_featured = EXCLUDED.is_featured,
         is_active = true,
         updated_at = now()`,
      [
        service.name,
        service.description,
        service.category,
        service.priceCents,
        service.durationMinutes,
        `/images/services/${service.image}.jpg`,
        service.isFeatured ?? false,
      ],
    );
  }
  return SERVICE_SEEDS.length;
}
