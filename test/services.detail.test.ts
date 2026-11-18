import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { buildTestApp } from './support/app';
import { insertCatalogue, resetServices } from './support/services';

const { app, db } = buildTestApp(undefined, {
  env: { PUBLIC_BASE_URL: 'https://api.example.test' },
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

const detail = (id: string) => request(app).get(`/services/${id}`);

function expectNotFound(res: request.Response) {
  expect(res.status).toBe(404);
  expect(res.body.success).toBe(false);
  expect(res.body.error.code).toBe('NOT_FOUND');
}

describe('GET /services/:id', () => {
  it('returns the complete record for an active service, without authentication', async () => {
    const res = await detail(ids.swedish as string);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: true,
      data: {
        id: ids.swedish,
        name: 'Swedish Massage',
        description: 'A relaxing full-body treatment with long, flowing strokes.',
        price: 65,
        durationMinutes: 60,
        category: 'Wellness',
        imageUrl: 'https://api.example.test/images/services/swedish-massage.jpg',
        isFeatured: true,
      },
    });
  });

  it('matches what the list returns for the same service', async () => {
    const fromList = (await request(app).get('/services?q=laptop')).body.data[0];
    const fromDetail = (await detail(ids.laptop as string)).body.data;
    expect(fromDetail).toEqual(fromList);
  });

  describe('unknown ids are 404', () => {
    it('a well-formed id that does not exist', async () => {
      expectNotFound(await detail('00000000-0000-4000-8000-000000000000'));
    });

    it('an inactive service looks exactly like a missing one', async () => {
      const inactive = await detail(ids.retired as string);
      const missing = await detail('00000000-0000-4000-8000-000000000000');
      expectNotFound(inactive);
      expect(inactive.body).toEqual(missing.body);
    });
  });

  describe('malformed ids are 404, never a 500', () => {
    it.each([
      'not-a-uuid',
      '123',
      'abc',
      '00000000-0000-0000-0000-00000000000', // one character short
      '00000000-0000-0000-0000-0000000000000', // one character long
      'ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ',
      '1%27%20OR%20%271%27%3D%271',
      '..%2F..%2Fetc%2Fpasswd',
      'x'.repeat(500),
    ])('id %j', async (id) => {
      expectNotFound(await detail(id));
    });
  });

  it('accepts an upper-case UUID', async () => {
    const res = await detail((ids.swedish as string).toUpperCase());
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Swedish Massage');
  });
});
