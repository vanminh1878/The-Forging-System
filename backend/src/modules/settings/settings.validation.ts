import { z } from 'zod';
import { badRequest } from '../../common/errors/app-error';
import { CONFIG_GROUPS } from './settings.catalog';
import type { ConfigDefinition } from './settings.catalog';

export const settingsKeyParam = z.object({ key: z.string().min(2).max(80).regex(/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/) });
export const settingsQuery = z.object({ group: z.enum(CONFIG_GROUPS).optional(), q: z.string().trim().max(100).optional() }).strict();
export const settingsValueBody = z.object({
  value: z.union([z.number().finite(), z.boolean(), z.string(), z.record(z.unknown()), z.array(z.unknown())]),
  reason: z.string().trim().min(3).max(500).optional(),
}).strict();

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };
const jsonValue: z.ZodType<JsonValue> = z.lazy(() => z.union([
  z.string(), z.number().finite(), z.boolean(), z.null(), z.array(jsonValue), z.record(jsonValue),
]));

export function validateConfigValue(def: ConfigDefinition, value: unknown): void {
  let schema: z.ZodTypeAny;
  switch (def.type) {
    case 'INT':
    case 'DECIMAL': {
      let number = z.number().finite();
      if (def.type === 'INT') number = number.int().min(-2_147_483_648).max(2_147_483_647);
      if (def.min !== undefined) number = number.min(def.min);
      if (def.max !== undefined) number = number.max(def.max);
      schema = number;
      break;
    }
    case 'BOOL': schema = z.boolean(); break;
    case 'TEXT': schema = z.string().max(2000); break;
    case 'TIME': schema = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/); break;
    case 'JSON': schema = z.union([z.record(jsonValue), z.array(jsonValue)]); break;
  }
  if (def.key === 'streak.milestones') {
    schema = z.record(z.string().regex(/^[1-9]\d*$/).refine((key) => Number(key) <= 2_147_483_647), z.number().int().min(0).max(2_147_483_647));
  }
  const result = schema.safeParse(value);
  if (!result.success) throw badRequest(`Giá trị cấu hình "${def.key}" không hợp lệ.`, result.error.issues, 'INVALID_CONFIG_VALUE');
}
