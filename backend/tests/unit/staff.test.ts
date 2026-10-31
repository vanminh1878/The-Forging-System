import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../../src/config/env', () => ({ env: { BCRYPT_ROUNDS: 4 }, isTest: true }));
vi.mock('../../src/db/sql', () => ({ sql: { one: vi.fn() } }));
import { sql } from '../../src/db/sql';
import { StaffService } from '../../src/modules/staff/staff.service';
import type { StaffRepository, StaffView } from '../../src/modules/staff/staff.repository';
import type { AuditService } from '../../src/modules/audit/audit.service';
import type { SettingsService } from '../../src/modules/settings/settings.service';
import { verifyPassword } from '../../src/common/utils/password';

describe('staff business rules', () => {
  const actor = { userId: 'admin-id', roles: ['ADMIN'] as const, branchId: null };
  // Mutable roles are required by the application's AuthContext.
  const admin = { ...actor, roles: [...actor.roles] };
  const staff: StaffView = { id: 'staff-id', fullName: 'Coach Test', phone: '0901234567', email: null, roles: ['COACH'], branchId: 'branch-id', branchName: 'Quận 7', accountStatus: 'ACTIVE', mustChangePassword: true };
  const repo = {
    find: vi.fn(), create: vi.fn(), grant: vi.fn(), lockDirectory: vi.fn(), revokeRoles: vi.fn(),
    updateBranch: vi.fn(), updateStatus: vi.fn(), revokeSessions: vi.fn(), setTemporaryPassword: vi.fn(),
  };
  const audit = { record: vi.fn() };
  const settings = { getNumber: vi.fn() };
  const service = new StaffService(repo as unknown as StaffRepository, audit as unknown as AuditService, settings as unknown as SettingsService);

  beforeEach(() => {
    vi.resetAllMocks();
    repo.find.mockResolvedValue(staff);
    repo.create.mockResolvedValue(staff.id);
    settings.getNumber.mockResolvedValue(8);
  });

  it('hashes generated temporary passwords, normalizes contacts, and keeps secrets out of audit', async () => {
    vi.mocked(sql.one).mockResolvedValueOnce({ id: 'branch-id' }).mockResolvedValueOnce(null);
    const result = await service.create({ fullName: staff.fullName, email: 'COACH@EXAMPLE.COM', phone: '0901234567', role: 'COACH', branchId: 'branch-id' }, admin);
    const input = repo.create.mock.calls[0][0];
    expect(input.email).toBe('coach@example.com');
    expect(await verifyPassword(result.temporaryPassword, input.passwordHash)).toBe(true);
    expect(repo.grant).toHaveBeenCalledWith(staff.id, 'COACH', admin.userId);
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain(result.temporaryPassword);
  });

  it('rejects duplicate contacts before creating an account', async () => {
    vi.mocked(sql.one).mockResolvedValueOnce({ id: 'branch-id' }).mockResolvedValueOnce({ id: 'existing-id' });
    await expect(service.create({ fullName: staff.fullName, phone: staff.phone!, role: 'COACH', branchId: 'branch-id' }, admin)).rejects.toMatchObject({ code: 'STAFF_CONTACT_TAKEN' });
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('rejects inactive or unknown branches', async () => {
    vi.mocked(sql.one).mockResolvedValueOnce(null);
    await expect(service.create({ fullName: staff.fullName, phone: staff.phone!, role: 'COACH', branchId: 'branch-id' }, admin)).rejects.toMatchObject({ code: 'INVALID_BRANCH' });
  });

  it('prevents an ordinary Admin from provisioning or resetting Super Admins', async () => {
    await expect(service.create({ fullName: staff.fullName, phone: staff.phone!, role: 'SUPER_ADMIN', branchId: 'branch-id' }, admin)).rejects.toMatchObject({ status: 403 });
    repo.find.mockResolvedValue({ ...staff, roles: ['SUPER_ADMIN'] });
    await expect(service.resetPassword(staff.id, 'Reset test', admin)).rejects.toMatchObject({ status: 403 });
    expect(repo.setTemporaryPassword).not.toHaveBeenCalled();
  });

  it('retains role history and revokes credentials on reassignment', async () => {
    await service.update(staff.id, { role: 'RECEPTIONIST', reason: 'Chuyển vai trò' }, admin);
    expect(repo.revokeRoles).toHaveBeenCalledWith(staff.id, admin.userId);
    expect(repo.grant).toHaveBeenCalledWith(staff.id, 'RECEPTIONIST', admin.userId);
    expect(repo.revokeSessions).toHaveBeenCalledWith(staff.id);
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ action: 'STAFF_UPDATED', reason: 'Chuyển vai trò' }));
  });

  it('protects the last active Super Admin from disabling or demotion', async () => {
    repo.find.mockResolvedValue({ ...staff, roles: ['SUPER_ADMIN'] });
    vi.mocked(sql.one).mockResolvedValue({ total: 1 });
    const superAdmin = { ...admin, roles: ['SUPER_ADMIN' as const] };
    await expect(service.setStatus(staff.id, 'DISABLED', 'Test', superAdmin)).rejects.toMatchObject({ code: 'LAST_SUPER_ADMIN' });
    await expect(service.update(staff.id, { role: 'COACH', reason: 'Test' }, superAdmin)).rejects.toMatchObject({ code: 'LAST_SUPER_ADMIN' });
    expect(repo.updateStatus).not.toHaveBeenCalled();
    expect(repo.revokeRoles).not.toHaveBeenCalled();
  });

  it('resets password with a new temporary credential and revokes all sessions', async () => {
    const result = await service.resetPassword(staff.id, 'Quên mật khẩu', admin);
    expect(result.mustChangePassword).toBe(true);
    expect(await verifyPassword(result.temporaryPassword, repo.setTemporaryPassword.mock.calls[0][1])).toBe(true);
    expect(repo.revokeSessions).toHaveBeenCalledWith(staff.id);
    expect(JSON.stringify(audit.record.mock.calls)).not.toContain(result.temporaryPassword);
  });
});
