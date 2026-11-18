import { readFileSync } from 'node:fs';
import path from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { createTestDb } from './support/db';

const readme = readFileSync(path.resolve(__dirname, '../README.md'), 'utf8');
const db = createTestDb();
afterAll(() => db.close());

/** Column names in the first column of the README's appointments table. */
function documentedColumns(): string[] {
  const section = readme.split('### The `appointments` table')[1]?.split(/\n#{1,3} /)[0] ?? '';
  return [...section.matchAll(/^\|\s*`([a-z_]+)`\s*\|/gm)].map((m) => m[1] as string);
}

describe('appointments schema documentation', () => {
  it('lists exactly the columns of the migrated table, with matching types', async () => {
    const { rows } = await db.query<{ column_name: string; udt_name: string }>(
      `SELECT column_name, udt_name FROM information_schema.columns
       WHERE table_name = 'appointments' ORDER BY ordinal_position`,
    );
    expect(documentedColumns().sort()).toEqual(rows.map((r) => r.column_name).sort());

    const typeInReadme = (column: string) =>
      new RegExp(`^\\|\\s*\`${column}\`\\s*\\|\\s*\`([a-z_]+)\``, 'm').exec(readme)?.[1];
    const aliases: Record<string, string> = { int4: 'integer', timestamptz: 'timestamptz' };
    for (const row of rows) {
      expect(typeInReadme(row.column_name), row.column_name).toBe(
        aliases[row.udt_name] ?? row.udt_name,
      );
    }
  });

  it('documents the overlap constraint that really exists', async () => {
    const { rows } = await db.query<{ conname: string }>(
      `SELECT conname FROM pg_constraint WHERE conrelid = 'appointments'::regclass AND contype = 'x'`,
    );
    expect(rows.map((r) => r.conname)).toEqual(['appointments_no_overlap']);
    expect(readme).toContain('appointments_no_overlap');
  });

  it('documents every appointment status', async () => {
    const { rows } = await db.query<{ enumlabel: string }>(
      `SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
       WHERE t.typname = 'appointment_status'`,
    );
    for (const { enumlabel } of rows) expect(readme).toContain(enumlabel);
  });
});
