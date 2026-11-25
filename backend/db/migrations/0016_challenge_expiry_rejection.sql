ALTER TABLE challenge_participations
  ADD COLUMN IF NOT EXISTS rejected_by uuid REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS rejected_at timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason text;

ALTER TABLE challenge_participations
  DROP CONSTRAINT IF EXISTS challenge_participations_status_check;

ALTER TABLE challenge_participations
  ADD CONSTRAINT challenge_participations_status_check
  CHECK (status IN ('PENDING_COACH','JOINED','AWAITING_COACH','REWARDED','REJECTED','EXPIRED'));

ALTER TABLE challenge_participations
  ADD CONSTRAINT challenge_participations_rejection_check
  CHECK (
    (status = 'REJECTED' AND rejected_by IS NOT NULL AND rejected_at IS NOT NULL AND rejection_reason IS NOT NULL)
    OR status <> 'REJECTED'
  );
