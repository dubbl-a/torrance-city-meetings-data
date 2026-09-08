-- One member's voting record, split by motion class.
--
-- Answers: on the motions where this member's vote value was published, how
-- did they vote, and how does that differ between procedural motions and
-- substantive ones? Edit the name in the params row; the values that work are
-- in meetings.members.canonical_name.
--
-- Caveat: this counts only rows with a published value, so it is a record of
-- what the sources say, not of every motion the member sat through. Motions
-- with a NULL motion_class have no verb the parser recognized and are shown
-- separately rather than folded into either class.

WITH params AS (SELECT 'George K Chen'::text AS member)
SELECT coalesce(mo.motion_class, '(no verb parsed)') AS motion_class,
       count(*) FILTER (WHERE v.vote_value = 'aye')     AS aye,
       count(*) FILTER (WHERE v.vote_value = 'no')      AS no,
       count(*) FILTER (WHERE v.vote_value = 'abstain') AS abstain,
       count(*) FILTER (WHERE v.vote_value = 'recused') AS recused,
       count(*) FILTER (WHERE v.vote_value = 'absent')  AS absent,
       count(*) FILTER (WHERE v.vote_value IS NULL)     AS value_not_published
  FROM meetings.votes v
  JOIN meetings.members mem ON mem.person_id = v.person_id
  JOIN meetings.motions mo  ON mo.motion_id  = v.motion_id
  JOIN params p ON p.member = mem.canonical_name
 GROUP BY 1
 ORDER BY 1;
