import type { RequestHandler } from 'express';

export type LogSink = (line: string) => void;

/**
 * Logs one line per request: method, path, status and duration.
 * Bodies, headers and query strings are deliberately never logged because they can
 * contain passwords and tokens.
 */
export function requestLogger(write: LogSink): RequestHandler {
  return (req, res, next) => {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - start) / 1e6;
      write(`${req.method} ${req.path} ${res.statusCode} ${ms.toFixed(1)}ms`);
    });
    next();
  };
}
