import type { Router } from 'express';
import { zodToJsonSchema } from 'zod-to-json-schema';
import type { ZodTypeAny } from 'zod';
import { requireAuth } from '../middlewares/auth.middleware';
import type { Schemas } from '../middlewares/validate.middleware';

/* eslint-disable @typescript-eslint/no-explicit-any -- walks express internals (Router.stack) */
type Json = Record<string, any>;

const METHODS = ['get', 'post', 'put', 'patch', 'delete'];
const SKIP_TAGS = ['admin', 'me'];

const schemaOf = (z: ZodTypeAny): Json => {
  const { $schema: _ignored, ...rest } = zodToJsonSchema(z, { target: 'openApi3', $refStrategy: 'none' }) as Json;
  return rest;
};

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
});

/** Mount prefix of a `router.use('/x', ...)` layer, recovered from its regexp (express 4 keeps no path). */
function mountPrefix(layer: any): string {
  const m = /^\^\\\/(.+?)\\\/\?\(\?=\\\/\|\$\)$/.exec(layer.regexp.source);
  return m ? `/${m[1].replace(/\\\//g, '/')}` : '';
}

interface Found {
  method: string;
  path: string;
  handlers: any[];
  guards: any[]; // handlers of preceding use() layers that match this path
}

function walk(router: Router, prefix: string, inherited: any[], out: Found[]): void {
  const stack: any[] = (router as any).stack;
  stack.forEach((layer, i) => {
    if (layer.route) {
      const routePath: string = layer.route.path;
      const guards = [...inherited];
      for (const prev of stack.slice(0, i)) {
        if (!prev.route && !prev.handle.stack && prev.match(routePath)) guards.push(prev.handle);
      }
      for (const method of METHODS) {
        if (layer.route.methods[method]) {
          out.push({ method, path: prefix + routePath, handlers: layer.route.stack.map((l: any) => l.handle), guards });
        }
      }
    } else if (layer.handle.stack) {
      // Nested router mounted with use('/x', router): guards declared before it that match the mount path also apply.
      const mount = mountPrefix(layer);
      const guards = [...inherited];
      for (const prev of stack.slice(0, i)) {
        if (!prev.route && !prev.handle.stack && prev.match(mount || '/')) guards.push(prev.handle);
      }
      walk(layer.handle, prefix + mount, guards, out);
    }
  });
}

/** Builds an OpenAPI 3 document from the routers: paths from the stack, schemas from validate(), roles from requireRoles(). */
export function buildOpenApi(routers: Router[]): Json {
  const found: Found[] = [];
  routers.forEach((r) => walk(r, '', [], found));

  const paths: Json = {};
  for (const f of found) {
    const all = [...f.guards, ...f.handlers];
    const secured = all.includes(requireAuth);
    const roles: string[] = [...new Set(all.flatMap((h) => (h.openapiRoles as string[] | undefined) ?? []))];
    const schemas: Schemas = Object.assign({}, ...all.filter((h) => h.openapi).map((h) => h.openapi));

    const parameters: Json[] = [{ $ref: '#/components/parameters/TenantCode' }];
    for (const [where, z] of [['path', schemas.params], ['query', schemas.query]] as const) {
      if (!z) continue;
      const s = schemaOf(z);
      for (const [name, prop] of Object.entries<Json>(s.properties ?? {})) {
        parameters.push({ name, in: where, required: where === 'path' || (s.required ?? []).includes(name), schema: prop });
      }
    }

    const path = f.path.replace(/:(\w+)/g, '{$1}');
    const tag = path.split('/').filter((p) => p && !SKIP_TAGS.includes(p))[0] ?? 'default';
    const op: Json = {
      tags: [tag],
      summary: `${f.method.toUpperCase()} ${path}`,
      parameters,
      responses: {
        [f.method === 'post' ? '201' : '200']: {
          description: 'Thành công. Bao dạng { data, meta? }',
          content: { 'application/json': { schema: { type: 'object', properties: { data: {}, meta: { type: 'object' } } } } },
        },
        400: errorResponse('Dữ liệu không hợp lệ'),
      },
    };
    if (schemas.body) op.requestBody = { required: true, content: { 'application/json': { schema: schemaOf(schemas.body) } } };
    if (path === '/uploads' && f.method === 'post') {
      op.requestBody = {
        required: true,
        content: { 'multipart/form-data': { schema: { type: 'object', required: ['file'], properties: { file: { type: 'string', format: 'binary' } } } } },
      };
    }
    if (secured) {
      op.security = [{ bearerAuth: [] }];
      op.responses[401] = errorResponse('Chưa đăng nhập hoặc token hết hạn');
    }
    if (roles.length) {
      op.description = `Vai trò: ${roles.join(', ')}`;
      op['x-roles'] = roles;
      op.responses[403] = errorResponse('Không đủ quyền');
    }
    (paths[path] ??= {})[f.method] = op;
  }

  return {
    openapi: '3.0.3',
    info: {
      title: 'HVP The Forging System API',
      version: '1.0.0',
      description:
        'Tài liệu sinh tự động từ zod schema trong validate() và requireRoles(). Cấu trúc chi tiết của response và quy tắc nghiệp vụ xem trong docs/api/*.md (hoặc docs/).',
    },
    servers: [{ url: '/api/v1' }],
    paths,
    components: {
      securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
      parameters: {
        TenantCode: {
          name: 'X-Tenant-Code',
          in: 'header',
          required: false,
          description: 'Mã tenant; bỏ trống thì dùng tenant mặc định',
          schema: { type: 'string' },
        },
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              required: ['code', 'message'],
              properties: { code: { type: 'string' }, message: { type: 'string' }, details: {} },
            },
          },
        },
      },
    },
  };
}
