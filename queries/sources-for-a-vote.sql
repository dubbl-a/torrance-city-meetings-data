-- The documents behind one member's votes on one date.
--
-- Answers: when this dataset says a member voted a certain way on an item,
-- what exactly was that read from, and where can I get the same bytes? Edit
-- the params row. This reads meetings.v_vote_sources, which puts three
-- documents beside every vote row: the one the value came from, the vote
-- panel the member list came from, and the clerk's index the motion was
-- parsed from. Each is a URL the city served (or, for an ASR envelope, a
-- local: name for the maintainer's transcription) plus a sha256 of the bytes.
--
-- Caveat: a NULL source_url beside a NULL vote_value is the expected shape,
-- because no document published a value. A NULL source_url beside a value
-- cannot occur; the publisher refuses it. panel_http_status = 500 means the
-- panel is partial (see README, "How to read the votes correctly").

WITH params AS (SELECT 'Councilmember Sheikh'::text AS member, DATE '2026-07-21' AS on_date)
SELECT s.item_number,
       s.vote_value,
       s.vote_value_source,
       s.panel_status,
       s.source_kind,
       s.source_url,
       s.source_sha256,
       s.panel_url,
       s.panel_http_status,
       s.structure_url
  FROM meetings.v_vote_sources s
  JOIN params p ON p.member = s.member_name AND p.on_date = s.meeting_date
 ORDER BY s.item_number;
