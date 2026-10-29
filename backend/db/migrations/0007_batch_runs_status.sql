-- INF-02: batch_runs records the outcome of every run (success, failure, skipped by lock).
-- The table stays append-only: one row is inserted when a run finishes.
alter table batch_runs
  add column status     text not null default 'SUCCESS' check (status in ('SUCCESS','FAILED','SKIPPED')),
  add column started_at timestamptz;

create index ix_batch_runs_key_run_at on batch_runs (tenant_id, batch_key, run_at desc);
