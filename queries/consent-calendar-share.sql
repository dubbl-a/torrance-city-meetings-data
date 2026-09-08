-- Consent-calendar share of substantive motions, per year.
--
-- Answers: how much of the council's substantive business passed in a consent
-- batch rather than as its own item? section_kind is the clerk's own agenda
-- section, collapsed to consent, hearing, administrative and so on.
--
-- Caveat: this filters to motion_class = 'substantive' on purpose. An
-- unfiltered motion count is mostly adjournments and waivers of further
-- reading, so any share computed over all motions moves with how many times
-- the council adjourned. Motions the clerk filed under no agenda item have no
-- section and are excluded from both sides of the ratio.

SELECT extract(year FROM m.meeting_date)::int AS year,
       count(*) FILTER (WHERE ai.section_kind = 'consent') AS consent_motions,
       count(*)                                            AS substantive_motions,
       round(100.0 * count(*) FILTER (WHERE ai.section_kind = 'consent')
             / nullif(count(*), 0), 1)                     AS consent_pct
  FROM meetings.motions mo
  JOIN meetings.agenda_items ai ON ai.agenda_item_id = mo.agenda_item_id
  JOIN meetings.meetings m      ON m.meeting_id = mo.meeting_id
 WHERE mo.motion_class = 'substantive'
 GROUP BY 1
 ORDER BY 1;
