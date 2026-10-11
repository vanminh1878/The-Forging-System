-- =====================================================================
-- 0003 - Rank promotion rules v4 (change request)
--   * ranks.min_active_months now means "months spent in the PREVIOUS rank"
--     (was: months since joining). Nothing is stored per member: the entry
--     date of the current rank comes from member_rank_history.earned_at.
--   * I->II 1 month, II->III 3, III->IV 6, IV->V 12 (DP + time, no trial).
--   * V->VI needs DP + a coach's Rank Trial, VI->VII needs DP + an admin's.
--     Ranks VI and VII have no waiting period.
-- Only data changes - no table is altered.
-- =====================================================================

update ranks set min_active_months = case rank_order
    when 2 then 1
    when 3 then 3
    when 4 then 6
    when 5 then 12
    else 0
  end;

update ranks set
    requires_trial = (rank_order >= 6),
    approval_role  = case rank_order when 6 then 'COACH' when 7 then 'ADMIN' else null end;

-- Ranks II-V no longer have a trial: close requests that are still waiting.
-- The next DP / course change (or a manual re-check) promotes those members.
update rank_trial_requests t
   set status = 'CANCELLED',
       result_note = coalesce(result_note, 'Hạng này không còn Rank Trial (quy tắc lên hạng v4).'),
       evaluated_at = now(),
       updated_at = now()
  from ranks r
 where r.id = t.target_rank_id
   and r.rank_order between 2 and 5
   and t.status in ('PENDING', 'SCHEDULED');
