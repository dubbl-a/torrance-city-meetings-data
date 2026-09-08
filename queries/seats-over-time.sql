-- Who held a seat, and over what window.
--
-- Answers: who sat on the body, in what role, and between which dates?
-- source_ref names the document the boundary was read off, usually the
-- resolution that installed the officers.
--
-- Caveat: the bounds are half-open and a NULL is not an unknown date. A NULL
-- valid_from means the evidence window starts later than the seat did, not that
-- the seat began on an unknown day; a NULL valid_to means the seat was still
-- held at the end of the window. A seat with no source_ref is one the corpus
-- can see the member holding without seeing either boundary.

SELECT mem.canonical_name,
       s.role,
       s.valid_from,
       s.valid_to,
       s.source_ref
  FROM meetings.seats s
  JOIN meetings.members mem ON mem.person_id = s.person_id
 WHERE s.body_slug = 'city-council'
 ORDER BY s.valid_from NULLS FIRST, mem.canonical_name;
