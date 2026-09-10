# Torrance City Council decisions, as a database

This repository is the documentation home for a read-only Postgres dataset of
what the Torrance City Council decided: its meetings, the agenda items it took
up, the motions made on them, and how each member was recorded voting. The data
is built from the City Clerk's own published record and is hosted on Neon, so
you query it with any standard Postgres client rather than downloading a file.
Nothing here is an interpretation of the record. Every row traces back to a
document the city published, and the columns that say how sure we are about a
value are part of the data rather than a footnote to it. It is maintained by
[Torrance Watch](https://torrancewatch.org), a nonpartisan civic reference for
the City of Torrance, and the underlying material is public record.

## What is in it

Ten tables and two views, all in the `meetings` schema.

- `bodies`: the city bodies covered. One row today, the City Council.
- `meetings`: one row per meeting, with its date, kind, and video link.
- `agenda_items`: the clerk's agenda, in order, nested into chapters.
- `item_identifiers`: ordinance, resolution, case, parcel and address numbers
  pulled out of agenda titles so they can be looked up exactly.
- `motions`: what was moved, by whom, seconded by whom, and the outcome, plus
  the archived index and vote panel it was read from.
- `votes`: one row per member per motion, with the vote value where a source
  published one, and the archived document that value was read from.
- `members`: the people the clerk's labels resolve to. Name only.
- `seats`: who held which seat, between which dates, and on what authority.
- `artifacts`: the provenance ledger. One row per source document fetched, with
  its URL, its sha256 and when it was retrieved.
- `publish_runs`: one row per publish, so you can see how fresh your copy is.
- `v_votes`: the view that joins a vote to its motion, agenda item and meeting.
- `v_vote_sources`: the same vote row beside the three documents behind it,
  each as a URL and a sha256.

## What is not in it

No transcripts and no speech of any kind. No speaker attribution. No contact
details, no email addresses, no addresses of private individuals, and no voter
records. Members appear as a name and an id and nothing else, because knowing
that "Councilmember Sheikh" and person 5745 are the same person is all a reader
of a voting record needs. Residents who spoke at a meeting do not appear here at
all.

## Coverage and freshness

102 meetings, from 2023-08-08 through 2026-09-01. Within that window: 2,688
agenda items, 904 motions, 6,206 vote rows, 230 item identifiers, 11 members,
12 seats and 1,242 provenance records. Of the 6,206 vote rows, 4,743 carry a
published vote value and 1,463 do not.

The maintainer republishes after each meeting cycle. To see when your copy was
last written and what landed in it, read `meetings.publish_runs`, which has one
row per applied run with a per-table JSON breakdown of source, upserted and
pruned row counts. `queries/freshness.sql` prints it. Publishing is not the same
as the record being complete: approved minutes are ratified weeks after the
meeting they describe, so the most recent meetings routinely arrive with their
vote values still unpublished.

## Where the data comes from

Three city sources, all of them documents the city published itself.

- The City Clerk's Granicus archive: the meeting index and the vote panels. This
  is where meetings, agenda items, motions and the list of who was recorded on
  each vote come from.
- PrimeGov: the city's current agenda system. Meeting clock times, agenda
  packets, and the ACTION Minutes for 2023 and 2024.
- Laserfiche: the City Clerk's repository of approved minutes for 2025 onward.

Every document fetched is archived and recorded in `meetings.artifacts` with its
source URL and a sha256 of the bytes, so any row in this dataset can be traced
to the exact file it was read from.

### The three vote sources

Granicus publishes who was on each vote panel and leaves the aye/no column
blank. Where a vote value exists, it was recovered from one of three records,
and `vote_value_source` says which. The three windows abut and never overlap, so
no meeting draws on two of them.

| Source | Window | What it is |
| --- | --- | --- |
| `action_minutes` | 2023 and 2024 | PrimeGov ACTION Minutes, which describe themselves as provisional on their own first page |
| `approved_minutes` | 2025 and 2026 | Minutes ratified by the City Clerk and Mayor, from Laserfiche |
| `transcript` | 2026-07-14 onward | The City Clerk's spoken announcement of the result, on meetings that have been transcribed |
| none | all windows | The member was recorded on the panel and no source published a value |

Recovery refuses more than it accepts. A value is written only when the
announced or minuted outcome matches the clerk's own index, every name resolves,
every named member is on that motion's own panel, and any stated tally is
arithmetically consistent with the attendance the same document states, with
one exception: on a `partial` panel the member the Clerk announces as recused or
abstaining is the missing row, written from the transcript. Where
those do not reconcile, nothing is written and the value stays blank. Refusing
is the intended outcome, not a gap waiting to be filled in.

## Getting access

The dataset is read-only and the connection string is handed out on request.
Open an issue on this repository and say briefly what you plan to do with it.
There is no fee and no approval committee. It is distributed out of band because
a shared credential in a public repository is a credential that gets abused, not
because the data is restricted. The URL looks like this, with the password in:

```
postgresql://meetings_reader:PASSWORD@ep-little-sun-ar2eiumm-pooler.c-4.us-west-2.aws.neon.tech/neondb?sslmode=require
```

The role is `meetings_reader`. It holds SELECT on the `meetings` schema and
nothing anywhere else, so there is no way to write, and no other schema in that
database is visible to it.

## Connecting

Command line, with psql:

```bash
psql "postgresql://meetings_reader:PASSWORD@ep-little-sun-ar2eiumm-pooler.c-4.us-west-2.aws.neon.tech/neondb?sslmode=require"
```

A GUI client such as DBeaver, TablePlus or pgAdmin: choose PostgreSQL, then

```
Host      ep-little-sun-ar2eiumm-pooler.c-4.us-west-2.aws.neon.tech
Port      5432
Database  neondb
User      meetings_reader
Password  (the one you were given)
SSL mode  require
```

Python, with psycopg:

```python
import os, psycopg

with psycopg.connect(os.environ["MEETINGS_URL"]) as conn:
    for row in conn.execute("SELECT meeting_date, title FROM meetings.meetings ORDER BY meeting_date DESC LIMIT 5"):
        print(row)
```

R, with DBI and RPostgres:

```r
library(DBI)
con <- dbConnect(RPostgres::Postgres(), 
                 host = "ep-little-sun-ar2eiumm-pooler.c-4.us-west-2.aws.neon.tech",
                 dbname = "neondb", user = "meetings_reader",
                 password = Sys.getenv("MEETINGS_PASSWORD"), sslmode = "require")
dbGetQuery(con, "SELECT count(*) FROM meetings.motions")
```

## Schema overview

The full DDL is in `schema.sql`, generated by the publisher. Field-by-field
meanings and reliability tiers are in `DATA-DICTIONARY.md`.

| Table | Primary key | Points at |
| --- | --- | --- |
| `bodies` | `body_slug` | nothing |
| `members` | `person_id` | nothing |
| `meetings` | `meeting_id` | `bodies` |
| `agenda_items` | `agenda_item_id` | `meetings` |
| `item_identifiers` | `identifier_id` | `agenda_items` |
| `motions` | `motion_id` | `meetings`, `agenda_items`, `members`, `artifacts` |
| `votes` | `vote_id` | `motions`, `members`, `artifacts` |
| `seats` | `person_id` plus `body_slug`, `role`, `valid_from` | `members`, `bodies` |
| `artifacts` | `artifact_id` | `meetings` |
| `publish_runs` | `run_id` | nothing |

The chain from a vote back to its context is
vote to motion to agenda item to meeting to body, and separately vote to member.
`meetings.v_votes` walks all of it for you with LEFT joins, which matters: a
motion the clerk filed under no agenda item is real, and an inner join would
drop exactly the rows worth checking on. `meetings.v_vote_sources` walks the
other direction, from a vote row to the documents it rests on: the one its
value was read from, the vote panel its member list came from, and the index
its motion was parsed from. `queries/sources-for-a-vote.sql` prints them for
one member on one date.

## Example queries

Eight more are in `queries/`, each with a header saying what it answers and
where it can mislead you. Three to start with.

Every recorded vote at one meeting:

```sql
SELECT item_number, canonical_name, coalesce(vote_value, '(not published)') AS vote,
       vote_value_source, outcome
  FROM meetings.v_votes
 WHERE meeting_date = DATE '2026-07-21'
 ORDER BY item_number, canonical_name;
```

The motions that did not pass:

```sql
SELECT m.meeting_date, ai.item_number, mo.motion_text
  FROM meetings.motions mo
  JOIN meetings.meetings m      ON m.meeting_id = mo.meeting_id
  LEFT JOIN meetings.agenda_items ai ON ai.agenda_item_id = mo.agenda_item_id
 WHERE mo.outcome = 'declined'
 ORDER BY m.meeting_date DESC;
```

Substantive motions per year, which is the count worth publishing:

```sql
SELECT extract(year FROM m.meeting_date)::int AS year,
       count(*) FILTER (WHERE mo.motion_class = 'substantive') AS substantive,
       count(*) FILTER (WHERE mo.motion_class = 'procedural')  AS procedural,
       count(*) AS all_motions
  FROM meetings.motions mo
  JOIN meetings.meetings m ON m.meeting_id = mo.meeting_id
 GROUP BY 1 ORDER BY 1;
```

## How to read the votes correctly

Five things will give you a wrong answer if you skip them.

**A blank `vote_value` is not a no, and not an absence.** A row in `votes` means
the member was recorded on that motion's vote panel. NULL in `vote_value` means
recorded, value not published, which is the Granicus default across the whole
corpus. `absent` is a different thing: it is a published value, stating that the
member was not there. Never count NULL rows into an aye total, and state your
denominator as rows with a published value.

**`vote_value_source` is not decoration.** A value from `approved_minutes` was
ratified by the Clerk and Mayor. A value from `action_minutes` came from a
document that calls itself provisional. A value from `transcript` was recovered
from the clerk's spoken announcement and reconciled against the written record
before being written down. They are all usable and they are not equally settled,
so carry the column through into anything you publish.

**A raw motion count is misleading.** Roughly 40 percent of motions are
procedural: adjourn, waive further reading, accept and file, close the public
hearing. An unfiltered tally mostly counts adjournments. Filter on
`motion_class`, and say which filter you used. A further 68 motions have no verb
the parser recognized, because the clerk typed the staff recommendation where
the verb goes; those are NULL rather than guessed at, and they need their own
decision in your denominator.

**`panel_status` says whether the member list is whole.** Granicus's vote-panel
page crashes on the row of any member who recused or abstained and returns the
rows it had rendered under an HTTP 500. Those rows are published and the motion
carries `panel_status = 'partial'`, citing a ledger row whose `http_status` is
500. The missing member is never inferred: on a transcribed meeting the Clerk's
announcement supplies the row (`vote_value_source = 'transcript'`, citing the ASR
envelope); otherwise the minutes name them later and until then a partial-panel
denominator is one member short. `none` means no panel was served.

**`member_name` is the clerk's label at that meeting, not a person.** It is the
identity of the panel row, and it changes when the office changes: the same
person appears as "Councilmember Kalani" before the July 2026 installation and
"Mayor Kalani" after. Join through `person_id` to `members.canonical_name` when
you want the person across time, and use `member_name` when you want what the
clerk wrote that night.

## Known gaps

Eight meetings between July 2024 and April 2025 have a meeting row and no
decision record: 2024-07-02, 2024-07-30, 2024-12-03, 2024-12-18, 2025-01-07,
2025-02-18, 2025-03-11 and 2025-04-01. For those dates the clerk's index
endpoint returns a caption stream rather than an agenda, so there is nothing to
parse. This is a source problem and refetching does not fix it. Two further
meetings have an agenda and no motions.

Vote values lag the meeting. Minutes are ratified weeks later, so recent
meetings arrive with `vote_value` blank and fill in on a later publish.

Nineteen motions across the window have a partial or absent vote panel because
of the Granicus recusal crash described under "How to read the votes
correctly"; `motions.panel_status` marks each. Of the seven newest, three carry
the Clerk's announced values, recusal included; four wait for the minutes.

Ten meeting rows, the eight caption-stream dates among them, are `regular`
with no agenda items and a zero-length recording: Granicus placeholders, kept
because the clerk's archive lists them.

Coverage is the City Council only. Commissions and committees are planned, and
the `bodies` table and the `body_slug` column on `meetings` are already in place
for them, which is why a single-row lookup table is there. Where two council
recordings share a date and a meeting kind, only one is ingested today, which
affects three dates in the window.

## License

The documentation, the schema file and the queries in this repository are
licensed CC BY 4.0. See `LICENSE`. The underlying records are public record and
carry no copyright claim from this project. If you use the data, a link back to
[torrancewatch.org](https://torrancewatch.org) is appreciated and not required.

## Reporting a data error

If a row disagrees with the city's own document, that is a bug and the
maintainer wants to know. Open an issue using the data error template, which
asks for the meeting date, the item number, what the source says, what the table
says, and a link to the source. A report with those five things can be verified
against the archived document in minutes. A report without them usually cannot
be acted on at all.

## Contributing

Corrections, query contributions and documentation fixes are welcome by pull
request against `main`. The queries in `queries/` should run as written against
the live database and carry a header comment saying what they answer and where
they mislead.

The content of this repository is generated and maintained from a private
publisher, so `schema.sql` and the row counts are written by tooling rather than
by hand. The `CLAUDE.md` and `house.json` files at the root, and the
`.house/`, `.claude/` and `scripts/house/` directories, are maintainer tooling
for that process and can be ignored by anyone reading or using the data.
