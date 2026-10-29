import { Router } from 'express';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { buildOpenApi } from '../../src/common/http/openapi';
import { requireAuth, requireRoles } from '../../src/common/middlewares/auth.middleware';
import { validate } from '../../src/common/middlewares/validate.middleware';

const noop = () => undefined;

describe('buildOpenApi', () => {
  const r = Router();
  r.get('/open', noop);
  const admin = Router();
  admin.use('/admin', requireAuth, requireRoles('ADMIN'));
  admin.put('/admin/things/:id', validate({ params: z.object({ id: z.string() }), query: z.object({ q: z.string().optional() }), body: z.object({ n: z.number() }) }), noop);
  const nested = Router().use('/auth', Router().post('/login', noop));
  const doc = buildOpenApi([r, admin, nested]);

  it('converts path params, query and body from validate()', () => {
    const op = doc.paths['/admin/things/{id}'].put;
    expect(op.tags).toEqual(['things']);
    expect(op.parameters).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: 'id', in: 'path', required: true }),
        expect.objectContaining({ name: 'q', in: 'query', required: false }),
      ]),
    );
    expect(op.requestBody.content['application/json'].schema.required).toEqual(['n']);
  });

  it('marks secured routes and roles, leaves public ones open', () => {
    const op = doc.paths['/admin/things/{id}'].put;
    expect(op.security).toEqual([{ bearerAuth: [] }]);
    expect(op['x-roles']).toEqual(['ADMIN']);
    expect(op.responses[403]).toBeDefined();
    expect(doc.paths['/open'].get.security).toBeUndefined();
    expect(doc.paths['/auth/login'].post.security).toBeUndefined();
  });
});
