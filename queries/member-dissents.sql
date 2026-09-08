-- One member's dissents, with the agenda item they were on.
--
-- Answers: which decisions did this member vote against, abstain on, or recuse
-- themselves from, and what were they about? Edit the params row; the values
-- that work are in meetings.members.canonical_name. This reads meetings.v_votes,
-- the one view, which joins vote to motion to agenda item to meeting.
--
-- Caveat: vote_value_source says which record the value came from, and the
-- three sources are not equally settled: approved_minutes are ratified by the
-- Clerk and Mayor, action_minutes call themselves provisional on their own
-- first page, and transcript is a value recovered from the clerk's spoken
-- announcement. A dissent that no source published is not in these rows at all,
-- so this is a floor on the member's dissents, not a complete list.

WITH params AS (SELECT 'Asam Muhammad Sheikh'::text AS member)
SELECT v.meeting_date,
       v.item_number,
       v.vote_value,
       v.vote_value_source,
       v.outcome,
       v.motion_class,
       v.title
  FROM meetings.v_votes v
  JOIN params p ON p.member = v.canonical_name
 WHERE v.vote_value IN ('no', 'abstain', 'recused')
 ORDER BY v.meeting_date DESC;
