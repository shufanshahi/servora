import { Pool, type QueryResult, type QueryResultRow } from 'pg';

export interface Db {
  pool: Pool;
  query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    params?: unknown[],
  ): Promise<QueryResult<T>>;
  /** Waits for in-flight queries and closes every connection. Safe to call once. */
  close(): Promise<void>;
}

/** Thin wrapper over a pg Pool. Connections are opened lazily on first query. */
export function createDb(connectionString: string): Db {
  const pool = new Pool({ connectionString, max: 10 });

  // An idle client erroring (for example the database restarting) must not crash the process.
  pool.on('error', (error) => {
    console.error('Unexpected PostgreSQL pool error:', error.message);
  });

  return {
    pool,
    query: (text, params) => pool.query(text, params),
    close: () => pool.end(),
  };
}
