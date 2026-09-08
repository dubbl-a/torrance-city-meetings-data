-- How fresh is this copy of the data?
--
-- Answers: when did the maintainer last republish, and how many rows landed in
-- each table? counts is a JSON object written inside the publish transaction,
-- with a source, upserted and pruned figure per table. A run whose upserted
-- figures are all zero republished data that had not changed.
--
-- Caveat: publish_runs records when the data was PUBLISHED, not how recent the
-- underlying meetings are. Approved minutes are ratified weeks after the
-- meeting they describe, so the most recent meetings can be present with their
-- vote values still unpublished. Compare the run time against
-- max(meeting_date) in meetings.meetings before concluding anything is missing.

SELECT run_id,
       finished_at,
       mode,
       brake_tripped,
       force_reason,
       key                          AS table_name,
       (value ->> 'source')::int    AS source_rows,
       (value ->> 'upserted')::int  AS upserted,
       (value ->> 'pruned')::int    AS pruned
  FROM meetings.publish_runs
  CROSS JOIN LATERAL jsonb_each(counts)
 ORDER BY run_id DESC, key;
