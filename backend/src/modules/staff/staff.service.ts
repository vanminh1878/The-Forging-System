import { badRequest, conflict, forbidden, notFound } from '../../common/errors/app-error';
import type { AuthContext } from '../../common/http/request-context';
import { randomToken } from '../../common/utils/ids';
import { hashPassword } from '../../common/utils/password';
import { isValidPhone, normalizePhone } from '../../common/utils/phone';
import { sql } from '../../db/sql';
import { Role } from '../../shared/roles';
import type { RoleCode } from '../../shared/roles';
import type { AuditService } from '../audit/audit.service';
import type { SettingsService } from '../settings/settings.service';
import type { StaffFilter, StaffRepository } from './staff.repository';

export class StaffService {
  constructor(private readonly repo: StaffRepository, private readonly audit: AuditService, private readonly settings: SettingsService) {}

  search(filter: StaffFilter, limit: number, offset: number) { return this.repo.search(filter, limit, offset); }
  async get(id: string) { const user = await this.repo.find(id); if (!user) throw notFound('Staff'); return user; }

  async create(input: { fullName: string; email?: string; phone?: string; role: RoleCode; branchId: string }, actor: AuthContext) {
    this.checkPrivilege(actor, [input.role]);
    await this.requireBranch(input.branchId);
    const phone = input.phone ? normalizePhone(input.phone) : null;
    const email = input.email?.toLowerCase() ?? null;
    if (phone && !isValidPhone(phone)) throw badRequest('Số điện thoại không hợp lệ.');
    if (await sql.one(`SELECT id FROM users WHERE ($1::text IS NOT NULL AND phone=$1) OR ($2::text IS NOT NULL AND email=$2)`, [phone, email])) {
      throw conflict('Email hoặc số điện thoại đã được đăng ký.', 'STAFF_CONTACT_TAKEN');
    }
    const temporaryPassword = await this.temporaryPassword();
    const id = await this.repo.create({ fullName: input.fullName, email, phone, passwordHash: await hashPassword(temporaryPassword), branchId: input.branchId });
    await this.repo.grant(id, input.role, actor.userId);
    const staff = await this.get(id);
    await this.audit.record({ actorId: actor.userId, action: 'STAFF_CREATED', entityType: 'USER', entityId: id, after: staff });
    return { staff, temporaryPassword };
  }

  private checkPrivilege(actor: AuthContext, roles: RoleCode[]) {
    if (roles.includes(Role.SUPER_ADMIN) && !actor.roles.includes(Role.SUPER_ADMIN)) throw forbidden('Chỉ Super Admin được quản lý Super Admin.');
  }
  private async requireBranch(id: string) {
    if (!await sql.one(`SELECT id FROM branches WHERE id=$1 AND is_active=true`, [id])) throw badRequest('Chi nhánh không tồn tại hoặc đã ngừng hoạt động.', undefined, 'INVALID_BRANCH');
  }
  private async temporaryPassword() { const min = await this.settings.getNumber('security.password_min_length'); return `${randomToken(Math.max(12, min))}a1`; }
}
