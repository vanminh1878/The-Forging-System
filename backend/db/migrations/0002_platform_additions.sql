-- =====================================================================
-- 0002 - Platform additions on top of schema v3.0
--   1) per-user read state for BROADCAST notifications
--   2) supporting indexes for the hot query paths
--   3) privileges for the non-owner runtime role (hvp_app)
-- The v3.0 tables themselves are never altered.
-- =====================================================================

-- 1) Broadcast notifications have no single owner, so "read" is tracked per user.
create table if not exists notification_reads (
  notification_id uuid not null references notifications(id) on delete cascade,
  user_id         uuid not null references users(id),
  tenant_id       uuid not null references tenants(id),
  read_at         timestamptz not null default now(),
  primary key (notification_id, user_id)
);
alter table notification_reads enable row level security;
create policy tenant_isolation on notification_reads
  using (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
  with check (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- 2) Indexes (v3.0 only declares uniqueness constraints).
create index if not exists ix_point_tx_member_time   on point_transactions (member_id, occurred_at desc);
create index if not exists ix_point_tx_member_source on point_transactions (member_id, source, occurred_at);
create index if not exists ix_attendance_member      on attendances (member_id, created_at desc);
create index if not exists ix_attendance_session     on attendances (session_id);
create index if not exists ix_sessions_start         on sessions (tenant_id, starts_at);
create index if not exists ix_sessions_branch_start  on sessions (branch_id, starts_at);
create index if not exists ix_sessions_coach_start   on sessions (coach_id, starts_at);
create index if not exists ix_memberships_member     on memberships (member_id, start_date desc);
create index if not exists ix_notifications_user     on notifications (user_id, created_at desc);
create index if not exists ix_notifications_bcast    on notifications (tenant_id, created_at desc) where user_id is null;
create index if not exists ix_staff_notif_role       on staff_notifications (tenant_id, to_role, created_at desc);
create index if not exists ix_redemptions_member     on redemptions (member_id, requested_at desc);
create index if not exists ix_redemptions_status     on redemptions (tenant_id, status, requested_at);
create index if not exists ix_audit_entity           on audit_logs (tenant_id, entity_type, entity_id);
create index if not exists ix_audit_time             on audit_logs (tenant_id, created_at desc);
create index if not exists ix_rank_history_member    on member_rank_history (member_id, earned_at desc);
create index if not exists ix_challenge_part_member  on challenge_participations (member_id, status);
create index if not exists ix_members_status         on members (tenant_id, status);
create index if not exists ix_users_phone            on users (tenant_id, phone);
create index if not exists ix_class_enroll_member    on class_enrollments (member_id) where status = 'ACTIVE';

-- 3) Runtime role. The API connects as hvp_app (no ownership, no BYPASSRLS), so
--    row level security is enforced. The role itself is created by the
--    environment (docker/postgres/init) - this block only grants privileges.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'hvp_app') then
    grant usage on schema public to hvp_app;
    grant select, insert, update, delete on all tables in schema public to hvp_app;
    grant usage, select on all sequences in schema public to hvp_app;
    alter default privileges in schema public grant select, insert, update, delete on tables to hvp_app;
    alter default privileges in schema public grant usage, select on sequences to hvp_app;
  end if;
end $$;
