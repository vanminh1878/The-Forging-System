import { z } from 'zod';
import { paginationQuery } from '../../common/http/pagination';

export const auditQuery = paginationQuery.extend({
  action: z.string().trim().min(1).max(100).optional(),
  entityType: z.string().trim().min(1).max(100).optional(),
  entityId: z.string().trim().min(1).max(256).optional(),
  actorId: z.string().uuid().optional(),
  actorType: z.enum(['USER', 'SYSTEM']).optional(),
  from: z.string().datetime({ offset: true }).optional(),
  to: z.string().datetime({ offset: true }).optional(),
  q: z.string().trim().max(100).optional(),
}).strict().refine((query) => !query.from || !query.to || new Date(query.from) <= new Date(query.to), {
  message: 'Thời gian bắt đầu phải trước hoặc bằng thời gian kết thúc.', path: ['to'],
});

export type AuditFilter = Omit<z.infer<typeof auditQuery>, 'page' | 'limit'>;
