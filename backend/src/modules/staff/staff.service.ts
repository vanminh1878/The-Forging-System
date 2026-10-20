import { notFound } from '../../common/errors/app-error';
import type { StaffFilter, StaffRepository } from './staff.repository';

export class StaffService {
  constructor(private readonly repo: StaffRepository) {}

  search(filter: StaffFilter, limit: number, offset: number) { return this.repo.search(filter, limit, offset); }
  async get(id: string) { const user = await this.repo.find(id); if (!user) throw notFound('Staff'); return user; }
}
