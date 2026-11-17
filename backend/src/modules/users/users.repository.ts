import type { Db } from '../../db/pool';

export interface UserRecord {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  createdAt: Date;
  updatedAt: Date;
}

/** The user shape that is safe to send to clients: never includes the password hash. */
export interface PublicUser {
  id: string;
  name: string;
  email: string;
  createdAt: string;
}

interface UserRow {
  id: string;
  name: string;
  email: string;
  password_hash: string;
  created_at: Date;
  updated_at: Date;
}

const COLUMNS = 'id, name, email, password_hash, created_at, updated_at';

function toRecord(row: UserRow): UserRecord {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    passwordHash: row.password_hash,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function toPublicUser(user: UserRecord): PublicUser {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    createdAt: user.createdAt.toISOString(),
  };
}

export class UsersRepository {
  constructor(private readonly db: Db) {}

  /** Inserts a user. Throws the raw PostgreSQL error (23505) when the email exists. */
  async create(input: { name: string; email: string; passwordHash: string }): Promise<UserRecord> {
    const result = await this.db.query<UserRow>(
      `INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING ${COLUMNS}`,
      [input.name, input.email, input.passwordHash],
    );
    return toRecord(result.rows[0] as UserRow);
  }

  /** Email comparison is case-insensitive (the column is citext). */
  async findByEmail(email: string): Promise<UserRecord | null> {
    const result = await this.db.query<UserRow>(`SELECT ${COLUMNS} FROM users WHERE email = $1`, [
      email,
    ]);
    const row = result.rows[0];
    return row ? toRecord(row) : null;
  }

  async findById(id: string): Promise<UserRecord | null> {
    const result = await this.db.query<UserRow>(`SELECT ${COLUMNS} FROM users WHERE id = $1`, [id]);
    const row = result.rows[0];
    return row ? toRecord(row) : null;
  }
}
