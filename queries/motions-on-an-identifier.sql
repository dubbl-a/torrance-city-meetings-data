-- Every motion on a given ordinance, resolution, case or address number.
--
-- Answers: what did the council do about Resolution 2026-66, and when? Edit the
-- params row. id_type is one of ordinance, resolution, case, apn or address;
-- canonical_value is the normalized form the parser stored, and display_value
-- is how the clerk wrote it in the agenda title.
--
-- Caveat: identifiers are pulled from the clerk's agenda title, so an item that
-- carries a number only inside its staff report will not be found here. Most of
-- the agenda has no identifier at all, and the words in the title are the only
-- way to reach it.

WITH params AS (SELECT 'resolution'::text AS id_type, '2026-66'::text AS value)
SELECT m.meeting_date,
       ai.item_number,
       ii.display_value,
       ai.title,
       mo.motion_text,
       mo.motion_class,
       mo.outcome
  FROM meetings.item_identifiers ii
  JOIN params p ON p.id_type = ii.id_type AND p.value = ii.canonical_value
  JOIN meetings.agenda_items ai ON ai.agenda_item_id = ii.agenda_item_id
  JOIN meetings.meetings m      ON m.meeting_id = ai.meeting_id
  LEFT JOIN meetings.motions mo ON mo.agenda_item_id = ai.agenda_item_id
 ORDER BY m.meeting_date, ai.ord;
