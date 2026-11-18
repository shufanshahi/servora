import type { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError, ERROR_CODES, notFound } from '../errors';

/** Maps a PostgreSQL error (identified by SQLSTATE) to a client-safe AppError. */
export type PgErrorMapper = (error: { code: string; constraint?: string }) => AppError | undefined;

const pgErrorMappers = new Map<string, PgErrorMapper>();

/**
 * Lets a module translate a database error code into an API error, for example
 * registerPgErrorMapper('23P01', () => conflict('SLOT_UNAVAILABLE', '...')).
 */
export function registerPgErrorMapper(sqlState: string, mapper: PgErrorMapper): void {
  pgErrorMappers.set(sqlState, mapper);
}

function isPgError(error: unknown): error is { code: string; constraint?: string } {
  return (
    typeof error === 'object' &&
    error !== null &&
    typeof (error as { code?: unknown }).code === 'string' &&
    /^[0-9A-Z]{5}$/.test((error as { code: string }).code)
  );
}

function bodyParserError(error: unknown): AppError | undefined {
  const type = (error as { type?: string } | null)?.type;
  if (type === 'entity.parse.failed')
    return new AppError(400, ERROR_CODES.BAD_REQUEST, 'Request body is not valid JSON');
  if (type === 'entity.too.large')
    return new AppError(413, ERROR_CODES.PAYLOAD_TOO_LARGE, 'Request body is too large');
  return undefined;
}

export const notFoundHandler: RequestHandler = (_req, _res, next) => {
  next(notFound('Route not found'));
};

export const errorHandler: ErrorRequestHandler = (error, _req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }

  let appError: AppError | undefined;
  if (error instanceof AppError) {
    appError = error;
  } else if (isPgError(error)) {
    appError = pgErrorMappers.get(error.code)?.(error);
  }
  appError ??= bodyParserError(error);

  if (!appError) {
    // Unexpected fault: log details server-side only, never send them to the client.
    console.error(
      'Unhandled error:',
      error instanceof Error ? (error.stack ?? error.message) : error,
    );
    res.status(500).json({
      success: false,
      error: { code: ERROR_CODES.INTERNAL_ERROR, message: 'Something went wrong' },
    });
    return;
  }

  res.status(appError.status).json({
    success: false,
    error: {
      code: appError.code,
      message: appError.message,
      ...(appError.details ? { details: appError.details } : {}),
    },
  });
};
