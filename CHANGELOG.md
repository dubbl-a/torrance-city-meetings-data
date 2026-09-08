# Changelog

Notable changes to this dataset and its documentation. Dates are the date of
publication.

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
