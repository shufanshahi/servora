import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const dir = path.resolve(__dirname, '../public/images/services');
const MAX_BYTES = 150 * 1024;
const images = readdirSync(dir)
  .filter((file) => file.endsWith('.jpg'))
  .sort();

/** Reads width and height from a JPEG's start-of-frame marker, or throws if it is malformed. */
function jpegSize(buffer: Buffer): { width: number; height: number } {
  if (buffer[0] !== 0xff || buffer[1] !== 0xd8) throw new Error('missing JPEG start marker');
  let offset = 2;
  while (offset + 9 < buffer.length) {
    if (buffer[offset] !== 0xff) throw new Error(`bad marker at ${offset}`);
    const marker = buffer[offset + 1] as number;
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      return { height: buffer.readUInt16BE(offset + 5), width: buffer.readUInt16BE(offset + 7) };
    }
    offset += 2 + buffer.readUInt16BE(offset + 2);
  }
  throw new Error('no frame header found');
}

describe('service images', () => {
  it('has about ten images', () => {
    expect(images.length).toBeGreaterThanOrEqual(10);
  });

  describe.each(images)('%s', (file) => {
    const buffer = readFileSync(path.join(dir, file));

    it('is a complete JPEG', () => {
      expect([...buffer.subarray(0, 3)]).toEqual([0xff, 0xd8, 0xff]);
      expect([...buffer.subarray(-2)]).toEqual([0xff, 0xd9]); // not truncated
    });

    it('is 800 x 600', () => {
      expect(jpegSize(buffer)).toEqual({ width: 800, height: 600 });
    });

    it(`is under ${MAX_BYTES / 1024} KB`, () => {
      expect(statSync(path.join(dir, file)).size).toBeLessThanOrEqual(MAX_BYTES);
    });
  });
});

describe('ATTRIBUTION.md', () => {
  const text = readFileSync(path.join(dir, 'ATTRIBUTION.md'), 'utf8');
  const rows = text
    .split('\n')
    .filter((line) => /^\| `[a-z0-9-]+\.jpg` \|/.test(line))
    .map((line) =>
      line
        .split('|')
        .map((cell) => cell.trim())
        .slice(1, -1),
    );

  const entries = new Map(rows.map((cells) => [cells[0]?.replaceAll('`', '') as string, cells]));

  it('has an entry for every image, and no entry without an image', () => {
    expect([...entries.keys()].sort()).toEqual(images);
  });

  describe.each(images)('%s', (file) => {
    const cells = entries.get(file) ?? [];
    const [, , original, author, licence, source] = cells;

    it('names the original file and its author', () => {
      expect(original, 'original file').toMatch(/\.jpe?g$/i);
      expect((author ?? '').length, 'author').toBeGreaterThan(1);
    });

    it('has a licence that permits reuse, with a link', () => {
      expect(licence).toMatch(/^\[Unsplash License\]\(https:\/\/unsplash\.com\/license\)$/);
    });

    it('links to the original photo on Unsplash', () => {
      expect(source).toMatch(/^<https:\/\/images\.unsplash\.com\/photo-[0-9a-f-]+>$/);
    });
  });

  it('states that the images were modified', () => {
    expect(text).toMatch(/modified/i);
    expect(text).toMatch(/cropped/i);
    expect(text).toMatch(/resized/i);
  });

  it('allows no non-commercial or no-derivatives licence', () => {
    expect(text).not.toMatch(/\bCC BY-NC|\bNC-ND|\bND\b/);
  });
});
