-- STK-02: the registered weekly streak job must be accepted by batch_runs.
alter table batch_runs drop constraint batch_runs_batch_key_check;
alter table batch_runs add constraint batch_runs_batch_key_check check (batch_key in
  ('expiry','reminder','inactive','streak','comeback','challenge','nudge','armory','sessions','streak-weekly-close'));
