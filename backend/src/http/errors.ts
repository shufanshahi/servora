/**
 * Stable, machine-readable error codes returned in `error.code`.
 * Every code here must be documented in README.md (enforced by a test).
 * Domain-specific codes (for example SLOT_UNAVAILABLE) are added by the change that owns them.
 */
export const ERROR_CODES = {
  BAD_REQUEST: 'BAD_REQUEST',
  UNAUTHENTICATED: 'UNAUTHENTICATED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  EMAIL_TAKEN: 'EMAIL_TAKEN',
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
} as const;

export interface FieldError {
  field: string;
  message: string;
}

/** An error whose status, code and message are safe to show to API clients. */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: FieldError[],
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const badRequest = (message = 'Malformed request'): AppError =>
  new AppError(400, ERROR_CODES.BAD_REQUEST, message);

export const unauthenticated = (message = 'Authentication required'): AppError =>
  new AppError(401, ERROR_CODES.UNAUTHENTICATED, message);

export const forbidden = (message = 'You are not allowed to do that'): AppError =>
  new AppError(403, ERROR_CODES.FORBIDDEN, message);

export const notFound = (message = 'Resource not found'): AppError =>
  new AppError(404, ERROR_CODES.NOT_FOUND, message);

/** 409 with a domain-specific code, e.g. conflict('EMAIL_TAKEN', '...'). */
export const conflict = (code: string, message: string): AppError =>
  new AppError(409, code, message);

export const validationError = (details: FieldError[], message = 'Validation failed'): AppError =>
  new AppError(422, ERROR_CODES.VALIDATION_ERROR, message, details);

export const rateLimited = (message = 'Too many requests, please try again later'): AppError =>
  new AppError(429, ERROR_CODES.RATE_LIMITED, message);

/** Registration with an email that already has an account (409). */
export const emailTaken = (): AppError =>
  conflict(ERROR_CODES.EMAIL_TAKEN, 'An account with this email already exists');

/**
 * Wrong email or wrong password (401). Both cases use this one message so a caller
 * cannot tell which emails are registered.
 */
export const invalidCredentials = (): AppError =>
  new AppError(401, ERROR_CODES.INVALID_CREDENTIALS, 'Incorrect email or password');
