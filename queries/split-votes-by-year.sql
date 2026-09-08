-- Split votes by year.
--
-- Answers: how often did the council divide, rather than vote as one, in each
-- calendar year? A motion counts as split when at least one member is recorded
-- with a published "no", "abstain" or "recused" value.
--
-- Caveat: a motion whose vote values were never published cannot be counted as
-- split or as unanimous, so the denominator here is motions with at least one
-- published value, not all motions. The "no_published_values" column is the
-- rest, and it is large for 2026, where the only source is the clerk's spoken
-- announcement on the meetings that have been transcribed.

SELECT extract(year FROM m.meeting_date)::int         AS year,
       count(*) FILTER (WHERE v.published > 0
                          AND v.dissenting > 0)       AS split,
       count(*) FILTER (WHERE v.published > 0
                          AND v.dissenting = 0)       AS unanimous_as_published,
       count(*) FILTER (WHERE v.published = 0)        AS no_published_values,
       count(*)                                       AS motions
  FROM meetings.motions mo
  JOIN meetings.meetings m ON m.meeting_id = mo.meeting_id
  JOIN LATERAL (
        SELECT count(*) FILTER (WHERE vote_value IS NOT NULL)                    AS published,
               count(*) FILTER (WHERE vote_value IN ('no', 'abstain', 'recused')) AS dissenting
          FROM meetings.votes
         WHERE motion_id = mo.motion_id
       ) v ON true
 GROUP BY 1
 ORDER BY 1;
