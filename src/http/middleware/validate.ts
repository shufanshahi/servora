import type { RequestHandler } from 'express';
import type { ZodType } from 'zod';
import { validationError, type FieldError } from '../errors';

interface Schemas {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
}

/**
 * Validates body, query and params before any business logic runs.
 * Parsed values replace the originals, so unknown fields are stripped and never reach
 * the service layer. Failures become a 422 VALIDATION_ERROR with per-field details.
 */
export function validate(schemas: Schemas): RequestHandler {
  return (req, _res, next) => {
    const details: FieldError[] = [];

    for (const part of ['params', 'query', 'body'] as const) {
      const schema = schemas[part];
      if (!schema) continue;

      const result = schema.safeParse(part === 'body' ? (req.body ?? {}) : req[part]);
      if (!result.success) {
        for (const issue of result.error.issues) {
          const path = issue.path.join('.');
          details.push({
            field: path ? `${part === 'body' ? '' : `${part}.`}${path}` : part,
            message: issue.message,
          });
        }
        continue;
      }

      if (part === 'query') {
        // Express 5 exposes req.query as a read-only getter, so redefine it.
        Object.defineProperty(req, 'query', {
          value: result.data,
          writable: true,
          configurable: true,
        });
      } else {
        (req as unknown as Record<string, unknown>)[part] = result.data;
      }
    }

    next(details.length > 0 ? validationError(details) : undefined);
  };
}
