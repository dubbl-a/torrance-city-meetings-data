# Changelog

Notable changes to this dataset and its documentation. Dates are the date of
publication.

## 2026-09-09

### Added

- Row-level provenance. `votes.source_artifact_id` names the archived
  document every published vote value was read from, and
  `motions.structure_artifact_id` and `motions.panel_artifact_id` name the
  clerk's index and the vote panel each motion was parsed from. All three
  are foreign keys into `artifacts`, so the tie is a join rather than a
  naming convention. A value with no citation cannot be published.
- `meetings.v_vote_sources`, a second view: every vote row beside the three
  documents behind it, each as a URL and a sha256. `queries/sources-for-a-vote.sql`
  prints them for one member on one date.
- `motions.panel_status` (`complete`, `partial`, `none`). Granicus's vote-panel
  page crashes on any panel carrying a recusal or abstention and returns the
  rows it had rendered under an HTTP 500; those rows are now archived, with
  their real status, and published, and the motion says the member set is
  incomplete. 21 motions across the window are `partial`.

### Updated

- 693 more vote rows carry a published value (4,743 of 6,206, up from 4,064 of
  6,050). Nine approved-minutes documents that are image-only scans are now
  read by OCR behind the same reconciliation gate, which is most of the gain
  for 2025; the partial panels above add member rows on 21 motions; and one
  clerk spelling ("Martucci" for Councilmember Mattucci, 2025-03-25) is
  repaired by an exact, curated table rather than a fuzzy match.
- The 89 vote rows on 2026-08-25 and 2026-09-01 that had no `person_id`, and
  the District 4 seat that was missing from `seats`, are fixed. A check on the
  maintainer's side now refuses to publish an unresolved panel row.
- README and data dictionary describe the two views, the source-kind
  mapping, `panel_status`, and the ten placeholder meeting rows.

## 2026-09-08

### Added

- Initial publication. The Torrance City Council decision record is readable as
  a Postgres dataset on Neon, covering 102 meetings from 2023-08-08 through
  2026-09-01: 2,688 agenda items, 904 motions, 6,050 per-member vote rows, 230
  item identifiers, 11 members, 12 seats and 1,190 provenance records.
- 4,064 of the 6,050 vote rows carry a published vote value, recovered from
  PrimeGov action minutes for 2023 and 2024, Laserfiche approved minutes for
  2025 and 2026, and the City Clerk's spoken announcement from 2026-07-14
  onward. The remaining 1,986 are rows where the member was recorded and no
  source published a value.
- This repository: `README.md`, `DATA-DICTIONARY.md`, `schema.sql` and eight
  worked queries in `queries/`.
