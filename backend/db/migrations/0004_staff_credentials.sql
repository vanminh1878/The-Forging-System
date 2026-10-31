-- STF-04: forced first-use password change and immediate credential revocation.
ALTER TABLE users
  ADD COLUMN must_change_password boolean NOT NULL DEFAULT false,
  ADD COLUMN auth_version integer NOT NULL DEFAULT 0 CHECK (auth_version >= 0);

CREATE INDEX ix_staff_directory ON users (tenant_id, branch_id, account_status, full_name);
