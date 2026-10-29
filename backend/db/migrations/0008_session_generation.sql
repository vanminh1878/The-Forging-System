-- CLS-02: generating sessions from class schedules must be idempotent.
create unique index ux_sessions_class_start on sessions (class_id, starts_at)
  where class_id is not null and status <> 'CANCELLED';

alter table batch_runs drop constraint batch_runs_batch_key_check;
alter table batch_runs add constraint batch_runs_batch_key_check check (batch_key in
  ('expiry','reminder','inactive','streak','comeback','challenge','nudge','armory','sessions'));

-- New setting group for classes.session_horizon_days.
alter table system_configs drop constraint system_configs_config_group_check;
alter table system_configs add constraint system_configs_config_group_check check (config_group in
  ('POINTS','RANK','STREAK','CHALLENGE','ARMORY','MEMBERSHIP','NOTIFICATION','CHECKIN','SECURITY','CLASS'));
