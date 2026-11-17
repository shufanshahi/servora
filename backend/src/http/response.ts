import type { Response } from 'express';

export interface PageMeta {
  page: number;
  limit: number;
  total: number;
}

/** 200 response in the standard success envelope. */
export function ok<T>(res: Response, data: T, meta?: PageMeta): Response {
  return res.status(200).json(meta ? { success: true, data, meta } : { success: true, data });
}

/** 201 response in the standard success envelope. */
export function created<T>(res: Response, data: T): Response {
  return res.status(201).json({ success: true, data });
}
