import { z } from 'zod';

export const paginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export interface Page {
  limit: number;
  offset: number;
  page: number;
}

export function toPage(q: { page: number; limit: number }): Page {
  return { limit: q.limit, offset: (q.page - 1) * q.limit, page: q.page };
}

export function pageMeta(page: Page, total: number) {
  return { page: page.page, limit: page.limit, total, totalPages: Math.max(1, Math.ceil(total / page.limit)) };
}
