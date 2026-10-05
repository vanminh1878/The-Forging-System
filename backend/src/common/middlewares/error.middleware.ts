import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../errors/app-error';
import { logger } from '../utils/logger';

export function notFoundHandler(_req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'ROUTE_NOT_FOUND', message: 'Route not found' } });
}

// Express recognises error middleware by its 4-argument signature.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request data',
        details: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      },
    });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message, details: err.details } });
    return;
  }
  // Postgres constraint violations raised by triggers / CHECKs surface as 409/422 instead of a blind 500.
  const pg = err as { code?: string; constraint?: string; message?: string };
  if (pg && typeof pg.code === 'string') {
    if (pg.code === '23505') {
      res.status(409).json({ error: { code: 'DUPLICATE', message: 'Duplicate record', details: pg.constraint } });
      return;
    }
    if (pg.code === '23514' || pg.code === 'P0001') {
      res.status(422).json({ error: { code: 'CONSTRAINT_VIOLATION', message: pg.message ?? 'Constraint violation' } });
      return;
    }
  }
  logger.error({ err, path: req.path }, 'unhandled error');
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } });
}
