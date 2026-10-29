import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny } from 'zod';

export interface Schemas {
  body?: ZodTypeAny;
  query?: ZodTypeAny;
  params?: ZodTypeAny;
}

/**
 * Validates and replaces body/query/params with the parsed (coerced) values.
 * Controllers can therefore trust their types and never validate by hand.
 */
export function validate(schemas: Schemas) {
  const middleware = (req: Request, _res: Response, next: NextFunction): void => {
    try {
      if (schemas.body) req.body = schemas.body.parse(req.body);
      if (schemas.query) Object.defineProperty(req, 'query', { value: schemas.query.parse(req.query), writable: true });
      if (schemas.params) req.params = schemas.params.parse(req.params);
      next();
    } catch (err) {
      next(err);
    }
  };
  // Read by common/http/openapi.ts to generate the API docs.
  return Object.assign(middleware, { openapi: schemas });
}
