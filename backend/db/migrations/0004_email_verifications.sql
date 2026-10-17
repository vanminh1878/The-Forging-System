-- =====================================================================
-- 0004 - E-mail OTP for registration
--   One row per OTP sent to an address that has no account yet. The row is
--   consumed (used_at) when the account is created.
-- =====================================================================
create table if not exists email_verifications (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id),
  email          citext not null,
  pin_hash       text not null,
  attempt_count  smallint not null default 0,
  expires_at     timestamptz not null,
  used_at        timestamptz,
  created_at     timestamptz not null default now()
);
alter table email_verifications enable row level security;
create policy tenant_isolation on email_verifications
  using (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
  with check (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

create index if not exists ix_email_verifications_email on email_verifications (tenant_id, email);
