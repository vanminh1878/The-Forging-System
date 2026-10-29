import { beforeAll, describe, expect, it } from 'vitest';
import { bootTestApp } from '../helpers/test-app';
import type { TestContext } from '../helpers/test-app';

describe('api docs', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await bootTestApp();
  });

  it('serves the generated OpenAPI document', async () => {
    const res = await ctx.api.get('/api/docs.json');
    expect(res.status).toBe(200);
    expect(res.body.openapi).toMatch(/^3\./);
    expect(res.body.paths['/me/profile'].patch.requestBody).toBeDefined();
    expect(res.body.paths['/admin/settings'].get.security).toEqual([{ bearerAuth: [] }]);
  });

  it('serves Swagger UI', async () => {
    const res = await ctx.api.get('/api/docs/');
    expect(res.status).toBe(200);
    expect(res.text).toContain('swagger-ui');
  });
});
