-- CFG-10: exact actor/action filters with stable newest-first pagination.
CREATE INDEX ix_audit_actor_time ON audit_logs (tenant_id,actor_id,created_at DESC,id DESC);
CREATE INDEX ix_audit_action_time ON audit_logs (tenant_id,action,created_at DESC,id DESC);
