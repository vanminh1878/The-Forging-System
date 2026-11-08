-- Challenge workflow: member requests participation, Coach approves it, then member submits completion evidence.
ALTER TABLE challenge_participations
  DROP CONSTRAINT IF EXISTS challenge_participations_status_check;

ALTER TABLE challenge_participations
  ADD CONSTRAINT challenge_participations_status_check
  CHECK (status IN ('PENDING_COACH','JOINED','AWAITING_COACH','REWARDED','EXPIRED'));
