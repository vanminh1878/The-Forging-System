import { describe, expect, it } from 'vitest';
import { CONFIG_BY_KEY, CONFIG_CATALOG } from '../../src/modules/settings/settings.catalog';
import type { ConfigDefinition } from '../../src/modules/settings/settings.catalog';
import { settingsQuery, settingsValueBody, validateConfigValue } from '../../src/modules/settings/settings.validation';

describe('CFG-01 settings validation', () => {
  it.each(CONFIG_CATALOG.map((def) => [def.key, def] as const))('accepts the default for %s', (_key, def) => {
    expect(() => validateConfigValue(def, def.defaultValue)).not.toThrow();
  });

  it.each([-1, 1.5, Infinity, NaN, '1200', true, 2_147_483_648])('rejects invalid monthly cap %j', (value) => {
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('points.dp_monthly_cap')!, value)).toThrow();
  });

  it('accepts zero cap but enforces thresholds and password maximum', () => {
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('points.dp_monthly_cap')!, 0)).not.toThrow();
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('points.completion_threshold')!, 101)).toThrow();
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('streak.weekly_min_sessions')!, 0)).toThrow();
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('security.password_min_length')!, 73)).toThrow();
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('rank.demotion_enabled')!, 'false')).toThrow();
  });

  it.each([[], null, 'invalid', { '0': 10 }, { '4': -1 }, { '4': 1.5 }, { '4': '20' }, { 'bad': 20 }])('rejects invalid milestone JSON %j', (value) => {
    expect(() => validateConfigValue(CONFIG_BY_KEY.get('streak.milestones')!, value)).toThrow();
  });

  it('validates TEXT, TIME, DECIMAL and JSON definitions without coercion', () => {
    const base: ConfigDefinition = { key: 'test.value', group: 'POINTS', type: 'TIME', description: 'Test', defaultValue: '23:59' };
    expect(() => validateConfigValue(base, '23:59:00')).not.toThrow();
    expect(() => validateConfigValue(base, '24:00')).toThrow();
    expect(() => validateConfigValue({ ...base, type: 'TEXT' }, 42)).toThrow();
    expect(() => validateConfigValue({ ...base, type: 'DECIMAL', min: 0, max: 1 }, 0.5)).not.toThrow();
    expect(() => validateConfigValue({ ...base, type: 'DECIMAL' }, Infinity)).toThrow();
    expect(() => validateConfigValue({ ...base, type: 'JSON' }, { invalid: undefined })).toThrow();
  });

  it('requires value, rejects unknown body keys and validates filter groups', () => {
    expect(settingsValueBody.safeParse({}).success).toBe(false);
    expect(settingsValueBody.safeParse({ value: 100, tenantId: 'other' }).success).toBe(false);
    expect(settingsValueBody.safeParse({ value: 100, reason: ' ' }).success).toBe(false);
    expect(settingsValueBody.safeParse({ value: false }).success).toBe(true);
    expect(settingsQuery.safeParse({ group: 'INVALID' }).success).toBe(false);
  });
});
