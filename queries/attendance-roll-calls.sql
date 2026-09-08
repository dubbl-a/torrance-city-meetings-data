-- Attendance as the clerk called it, meeting by meeting.
--
-- Answers: how many people did the clerk record as present, absent and excused,
-- and at what point in the recording? roll_calls is a JSON array with one entry
-- per roll call the clerk took, so a meeting with a late arrival has more than
-- one, and timeSeconds is an offset into the meeting video.
--
-- Caveat: roll calls are COUNTS and never names, and the counts include staff
-- the clerk called alongside the members, so a present figure above the seven
-- council seats is normal rather than an error. To find out who was recorded on
-- a particular decision, use meetings.votes, which is per member. A count the
-- parser could not read is stored as null, because "not stated" and "nobody"
-- are different facts. 91 of the 102 meetings carry at least one roll call.

SELECT m.meeting_date,
       m.meeting_kind,
       (rc.value ->> 'timeSeconds')::int AS at_video_second,
       (rc.value ->> 'present')::int     AS present,
       (rc.value ->> 'absent')::int      AS absent,
       (rc.value ->> 'excused')::int     AS excused
  FROM meetings.meetings m
  CROSS JOIN LATERAL jsonb_array_elements(m.roll_calls) AS rc(value)
 ORDER BY m.meeting_date DESC, at_video_second;
