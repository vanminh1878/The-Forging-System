-- Existing Challenges keep the legacy Coach-review + evidence workflow.
ALTER TABLE challenges
  ADD COLUMN IF NOT EXISTS join_approval text NOT NULL DEFAULT 'COACH'
    CHECK (join_approval IN ('AUTO', 'COACH')),
  ADD COLUMN IF NOT EXISTS completion_method text NOT NULL DEFAULT 'EVIDENCE'
    CHECK (completion_method IN ('ATTENDANCE', 'EVIDENCE'));
