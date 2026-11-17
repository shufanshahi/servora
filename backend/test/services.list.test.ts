import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { insertCatalogue, resetServices } from './support/services';

const { app, db } = buildTestApp(undefined, {
  env: { PUBLIC_BASE_URL: 'https://api.example.test/' },
});

let ids: Record<string, string>;
beforeAll(async () => {
  await resetServices(db);
  ids = await insertCatalogue(db);
});
afterAll(async () => {
  await resetServices(db);
  await db.close();
});

const list = (query = '') => request(app).get(`/services${query}`);
const names = (res: request.Response): string[] =>
  res.body.data.map((s: { name: string }) => s.name);

describe('GET /services', () => {
  describe('default listing', () => {
    it('needs no authentication', async () => {
      expect((await list()).status).toBe(200);
    });

    it('returns only active services, ordered by name, with pagination meta', async () => {
      const res = await list();
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(names(res)).toEqual([
        'Deep Tissue Massage',
        'Haircut & Styling',
        'Laptop Repair',
        'Manicure',
        'Private Yoga',
        'Spring Offer',
        'Swedish Massage',
      ]);
      expect(res.body.meta).toEqual({ page: 1, limit: 20, total: 7 });
    });

    it('returns the complete public shape, and nothing internal', async () => {
      const res = await list('?q=swedish');
      expect(res.body.data).toEqual([
        {
          id: ids.swedish,
          name: 'Swedish Massage',
          description: 'A relaxing full-body treatment with long, flowing strokes.',
          price: 65,
          durationMinutes: 60,
          category: 'Wellness',
          imageUrl: 'https://api.example.test/images/services/swedish-massage.jpg',
          isFeatured: true,
        },
      ]);
      const raw = JSON.stringify(res.body);
      expect(raw).not.toMatch(/price_cents|priceCents|is_active|isActive|image_path|imagePath/);
    });

    it('gives a null imageUrl when a service has no image', async () => {
      const res = await list('?q=manicure');
      expect(res.body.data[0].imageUrl).toBeNull();
    });

    it('formats prices as decimals', async () => {
      const res = await list('?q=haircut');
      expect(res.body.data[0].price).toBe(40);
      expect(typeof res.body.data[0].price).toBe('number');
    });
  });

  describe('inactive services', () => {
    it('never appear in lists, however you search', async () => {
      expect(names(await list())).not.toContain('Retired Service');
      expect(names(await list('?q=retired'))).toEqual([]);
      expect(names(await list('?category=Wellness'))).not.toContain('Retired Service');
      expect((await list('?q=retired')).body.meta.total).toBe(0);
    });
  });

  describe('text search', () => {
    it('matches the name in any letter case', async () => {
      const expected = ['Deep Tissue Massage', 'Swedish Massage'];
      for (const q of ['massage', 'MASSAGE', 'MaSsAgE']) {
        expect(names(await list(`?q=${q}`))).toEqual(expected);
      }
    });

    it('matches the description too', async () => {
      expect(names(await list('?q=stretching'))).toEqual(['Private Yoga']);
      expect(names(await list('?q=BLOW-DRY'))).toEqual(['Haircut & Styling']);
    });

    it('trims surrounding spaces and ignores a blank query', async () => {
      expect(names(await list('?q=%20%20yoga%20%20'))).toEqual(['Private Yoga']);
      expect((await list('?q=%20%20')).body.meta.total).toBe(7);
    });

    it('treats % and _ as plain characters, not wildcards', async () => {
      expect(names(await list('?q=50%25'))).toEqual(['Spring Offer']);
      expect(names(await list('?q=visits_this'))).toEqual(['Spring Offer']);
      expect(names(await list('?q=%25'))).toEqual(['Spring Offer']); // only text containing "%"
      expect(names(await list('?q=_'))).toEqual(['Spring Offer']); // only text containing "_"
      expect(names(await list('?q=a_c'))).toEqual([]); // "_" must not match any single character
    });

    it('survives SQL-injection style input as ordinary text', async () => {
      const res = await list(`?q=${encodeURIComponent("'; DROP TABLE services; --")}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
      expect((await list()).body.meta.total).toBe(7); // the table is still there
    });
  });

  describe('filters', () => {
    it('filters by category, case-insensitively', async () => {
      const wellness = ['Deep Tissue Massage', 'Private Yoga', 'Swedish Massage'];
      expect(names(await list('?category=Wellness'))).toEqual(wellness);
      expect(names(await list('?category=wellness'))).toEqual(wellness);
      expect(names(await list('?category=TECH%20SUPPORT'))).toEqual(['Laptop Repair']);
    });

    it('filters by price range, inclusive at both ends', async () => {
      expect(names(await list('?minPrice=40&maxPrice=45'))).toEqual([
        'Haircut & Styling',
        'Laptop Repair',
      ]);
      expect(names(await list('?maxPrice=25'))).toEqual(['Manicure']);
      expect(names(await list('?minPrice=95'))).toEqual(['Deep Tissue Massage']);
    });

    it('handles decimal price bounds', async () => {
      expect(names(await list('?minPrice=24.99&maxPrice=25.01'))).toEqual(['Manicure']);
    });

    it('combines category and price', async () => {
      expect(names(await list('?category=Wellness&maxPrice=60'))).toEqual(['Private Yoga']);
    });

    it('combines search, category, price and featured', async () => {
      const res = await list('?q=massage&category=wellness&minPrice=60&maxPrice=70&featured=true');
      expect(names(res)).toEqual(['Swedish Massage']);
    });

    it('returns only featured services when asked', async () => {
      expect(names(await list('?featured=true'))).toEqual([
        'Haircut & Styling',
        'Private Yoga',
        'Swedish Massage',
      ]);
      expect(names(await list('?featured=false'))).toEqual([
        'Deep Tissue Massage',
        'Laptop Repair',
        'Manicure',
        'Spring Offer',
      ]);
    });
  });

  describe('no matches', () => {
    it('is a normal 200 with an empty array and a total of 0', async () => {
      const res = await list('?q=zzzzzz');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        success: true,
        data: [],
        meta: { page: 1, limit: 20, total: 0 },
      });
    });

    it('also when filters contradict each other', async () => {
      const res = await list('?category=Beauty&minPrice=90');
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
      expect(res.body.meta.total).toBe(0);
    });
  });

  describe('invalid filters (422 VALIDATION_ERROR)', () => {
    it.each([
      ['minPrice=abc', 'minPrice'],
      ['maxPrice=ten', 'maxPrice'],
      ['minPrice=-5', 'minPrice'],
      ['minPrice=50&maxPrice=10', 'minPrice'],
      ['sort=created_at', 'sort'],
      ['sort=price%3B%20DROP%20TABLE%20services', 'sort'],
      ['order=sideways', 'order'],
      ['featured=maybe', 'featured'],
      ['page=0', 'page'],
      ['page=abc', 'page'],
      ['limit=0', 'limit'],
      ['limit=100', 'limit'],
    ])('%s is rejected on field %s', async (query, field) => {
      const res = await list(`?${query}`);
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      const fields = res.body.error.details.map((d: { field: string }) => d.field);
      expect(fields).toContain(`query.${field}`);
    });
  });

  describe('pagination', () => {
    it('returns the requested page and reports the overall total', async () => {
      const first = await list('?limit=3&page=1');
      const second = await list('?limit=3&page=2');
      const third = await list('?limit=3&page=3');
      expect(names(first)).toEqual(['Deep Tissue Massage', 'Haircut & Styling', 'Laptop Repair']);
      expect(names(second)).toEqual(['Manicure', 'Private Yoga', 'Spring Offer']);
      expect(names(third)).toEqual(['Swedish Massage']);
      for (const res of [first, second, third]) {
        expect(res.body.meta.total).toBe(7);
        expect(res.body.meta.limit).toBe(3);
      }
      expect(second.body.meta.page).toBe(2);
    });

    it('past the last page is an empty list that still shows the total', async () => {
      const res = await list('?limit=5&page=9');
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual([]);
      expect(res.body.meta).toEqual({ page: 9, limit: 5, total: 7 });
    });

    it('never repeats or skips a service across pages', async () => {
      const seen: string[] = [];
      for (let page = 1; page <= 4; page++) {
        seen.push(...names(await list(`?limit=2&page=${page}`)));
      }
      expect(seen).toHaveLength(7);
      expect(new Set(seen).size).toBe(7);
    });

    it('applies filters before counting the total', async () => {
      const res = await list('?category=Wellness&limit=2');
      expect(res.body.data).toHaveLength(2);
      expect(res.body.meta.total).toBe(3);
    });
  });

  describe('sorting', () => {
    it('sorts by price ascending and descending', async () => {
      expect(names(await list('?sort=price'))).toEqual([
        'Manicure',
        'Spring Offer',
        'Haircut & Styling',
        'Laptop Repair',
        'Private Yoga',
        'Swedish Massage',
        'Deep Tissue Massage',
      ]);
      expect(names(await list('?sort=price&order=desc'))[0]).toBe('Deep Tissue Massage');
    });

    it('sorts by name descending', async () => {
      expect(names(await list('?sort=name&order=desc'))[0]).toBe('Swedish Massage');
    });
  });

  describe('popular ordering', () => {
    it('is accepted and, with no bookings yet, equals name ordering', async () => {
      const popular = await list('?sort=popular');
      const byName = await list('?sort=name');
      expect(popular.status).toBe(200);
      expect(popular.body.data.map((s: { id: string }) => s.id)).toEqual(
        byName.body.data.map((s: { id: string }) => s.id),
      );
      expect(names(popular)).toEqual(names(byName));
    });

    it('works together with filters and paging', async () => {
      const res = await list('?sort=popular&category=Wellness&limit=2&page=2');
      expect(names(res)).toEqual(['Swedish Massage']);
      expect(res.body.meta.total).toBe(3);
    });
  });
});
