import { conflict, notFound } from '../../common/errors/app-error';
import { RoleGroup } from '../../shared/roles';
import type { BranchRepository } from './branch.repository';
import type { AuditService } from '../audit/audit.service';
import type { Branch, BranchInput } from './branch.types';

type Row = Branch & { qrVersion: string | null };

const isStaff = (roles: readonly string[]) =>
  roles.some((r) => (RoleGroup.STAFF as readonly string[]).includes(r));
const isAdmin = (roles: readonly string[]) =>
  roles.some((r) => (RoleGroup.ADMINS as readonly string[]).includes(r));

/** Members never see qrVersion; staff do. */
function present(row: Row, roles: readonly string[]): Branch {
  const { qrVersion, ...rest } = row;
  return isStaff(roles) ? { ...rest, qrVersion } : rest;
}

export class BranchService {
  constructor(
    private readonly repo: BranchRepository,
    private readonly audit: AuditService,
  ) {}

  async list(roles: readonly string[], includeInactive: boolean): Promise<Branch[]> {
    // Only admins may see inactive branches; everyone else silently gets the active ones.
    const rows = await this.repo.list(includeInactive && isAdmin(roles));
    return rows.map((r) => present(r, roles));
  }

  async get(id: string, roles: readonly string[]): Promise<Branch> {
    const row = await this.repo.findById(id);
    // Members must not learn that an inactive branch exists.
    if (!row || (!row.isActive && !isStaff(roles))) throw notFound('Chi nhánh');
    return present(row, roles);
  }

  private async assertCodeFree(code: string, exceptId?: string): Promise<void> {
    const hit = await this.repo.findByCode(code);
    if (hit && hit.id !== exceptId) throw conflict('Mã chi nhánh đã tồn tại', 'BRANCH_CODE_TAKEN');
  }

  async create(input: BranchInput & { code: string; name: string }, by: string): Promise<Branch> {
    await this.assertCodeFree(input.code);
    const row = await this.repo.insert(input);
    await this.audit.record({
      actorId: by,
      action: 'BRANCH_CREATED',
      entityType: 'BRANCH',
      entityId: row.id,
      after: row,
    });
    return row;
  }

  async update(id: string, patch: BranchInput, by: string): Promise<Branch> {
    const before = await this.repo.findById(id);
    if (!before) throw notFound('Chi nhánh');
    if (patch.code !== undefined && patch.code !== before.code) await this.assertCodeFree(patch.code, id);
    const after = (await this.repo.update(id, patch)) ?? before;
    await this.audit.record({
      actorId: by,
      action: 'BRANCH_UPDATED',
      entityType: 'BRANCH',
      entityId: id,
      before,
      after,
    });
    return after;
  }

  /** No-op (no audit) when the state does not change. */
  async setStatus(id: string, isActive: boolean, reason: string, by: string): Promise<Branch> {
    const before = await this.repo.findById(id);
    if (!before) throw notFound('Chi nhánh');
    if (before.isActive === isActive) return before;
    await this.repo.setActive(id, isActive);
    const after = { ...before, isActive };
    await this.audit.record({
      actorId: by,
      action: isActive ? 'BRANCH_ACTIVATED' : 'BRANCH_DEACTIVATED',
      entityType: 'BRANCH',
      entityId: id,
      before: { isActive: before.isActive },
      after: { isActive },
      reason,
    });
    return after;
  }

  /** Printable QR content for reception / print (rotating time-window codes are CHK-01). */
  async getQr(id: string): Promise<{ branchId: string; code: string; qrVersion: string; payload: string }> {
    const b = await this.repo.findById(id);
    if (!b) throw notFound('Chi nhánh');
    return qrOf(b);
  }

  /** Invalidates every check-in code issued under the previous version. */
  async rotateQr(id: string, reason: string | undefined, by: string) {
    const before = await this.repo.findById(id);
    if (!before) throw notFound('Chi nhánh');
    const qrVersion = await this.repo.bumpQrVersion(id, `HVP-${before.code}`);
    await this.audit.record({
      actorId: by,
      action: 'BRANCH_QR_UPDATED',
      entityType: 'BRANCH',
      entityId: id,
      before: { qrVersion: before.qrVersion },
      after: { qrVersion },
      reason: reason ?? 'Cập nhật QR check-in',
    });
    return qrOf({ ...before, qrVersion });
  }
}

function qrOf(b: { id: string; code: string; qrVersion: string | null }) {
  const qrVersion = b.qrVersion ?? '1';
  return { branchId: b.id, code: b.code, qrVersion, payload: `HVP|${b.code}|${qrVersion}` };
}
