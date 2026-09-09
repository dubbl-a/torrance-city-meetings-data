# Data dictionary

What every field in the `meetings` schema means, which document it traces to,
and how far you can lean on it. Adapted from the maintainer's internal
dictionary, cut down to the decision-record tables that are actually published.
The DDL itself is in `schema.sql`; this file is the reading guide for it.

The dataset genuinely mixes reliability tiers, and that is the main thing to
carry away. A motion the City Clerk logged and a vote value reconstructed from a
spoken announcement are not the same kind of fact, and the schema keeps them
apart rather than averaging them into one confident-looking column.

## Source-status tiers

Every field falls into one of three tiers.

**CERTIFIED.** Authored by the City Clerk and published as the meeting's own
record. Reproduced verbatim, nothing inferred. Meetings, agenda items, motions
and outcomes are all certified.

**USABLE.** Derived by a deterministic, tested rule from a certified source, or
recovered from a second city document and reconciled against the first. It is
good enough to count and to publish, and it is an editorial grouping or a
recovery rather than something the clerk stated in those words. `motion_verb`,
`motion_class`, recovered `vote_value`, and the roster dates in `seats` are all
usable.

**RECOVERED.** A `vote_value` that Granicus left blank and that a second record
supplied, always with `vote_value_source` naming which record. Recovery refuses
anything that does not reconcile, so a recovered value never passes as a
published one, and a refusal leaves the field NULL rather than guessing.

## The two hard caveats

These are the two ways to get a confidently wrong number out of this dataset.

**A raw motion count is misleading.** Around 40 percent of motions are
procedural: adjourn, waive further reading, accept and file, close the public
hearing. An unfiltered tally is mostly adjournments. Filter on `motion_class`
and state the denominator you used. 68 motions carry no `motion_verb` at all,
because the clerk typed the staff recommendation where the verb belongs;
inferring "approve" for those would put words in the council's mouth, so they
stay NULL and need their own decision in your denominator.

**A NULL `vote_value` is not a no and not an absence.** A row in `votes` means
the member was recorded on that motion's vote panel. NULL means recorded, value
not published. `absent` is a published value and a different fact. Neither is
the same as unknown. Any percentage over votes must say whether its denominator
is all rows or only rows with a published value.

## `meetings.bodies`

The registry every other table scopes to. One row today.

| Field | Meaning |
| --- | --- |
| `body_slug` | Primary key, and the value `meetings.body_slug` and `seats.body_slug` both reference. `city-council` today. |
| `name`, `body_kind` | Display name; one of council, commission, committee, board. |
| `granicus_view_id` | The body's Granicus archive view. Nullable, because PrimeGov carries bodies Granicus does not. |
| `seat_count` | What a full roster comes to. Not enforced: seats are derived from what the clerk recorded, and a vacancy is a fact about the body. |
| `is_active` | Whether the body still meets. |

## `meetings.meetings`

| Field | Meaning |
| --- | --- |
| `meeting_id` | Surrogate key. Vendor ids are attributes, because Torrance already moved agendas from Granicus to PrimeGov once. |
| `body_slug` | Which body met. Scope lives in this column rather than in table names. |
| `meeting_kind` | regular, special, closed-session-only or adjourned. Granicus does not qualify meeting names and PrimeGov does, so the more specific reading wins. |
| `meeting_date`, `started_at` | Date from Granicus. Clock time comes only from PrimeGov, so `started_at` is nullable and is not part of the natural key. |
| `duration_seconds` | Length of the recording where one exists, otherwise the last index timestamp, which is the adjournment motion and stops short of the recording's end. |
| `closed_session_spans` | Ranges in video seconds where the council was in closed session. Between a third and two thirds of a Torrance recording. |
| `roll_calls` | The clerk's attendance statements, as `[{timeSeconds, present, absent, excused}]`. **Counts, never names**, and they include staff called alongside the members, so a present figure above the seven seats is normal. A count the parser could not read is null rather than 0, because "not stated" and "nobody" are different facts. 91 of 102 meetings carry at least one. |
| `granicus_clip_id`, `primegov_meeting_id`, `video_url` | Vendor identifiers and the public video link. |

## `meetings.agenda_items`

Items form nested chapters rather than a flat list.

| Field | Meaning |
| --- | --- |
| `agenda_item_id` | Primary key. |
| `meeting_id` | The meeting. |
| `ord`, `item_number` | Position in the agenda, and the number the clerk printed. |
| `title` | The clerk's own agenda title, verbatim. For most of the corpus this is the only searchable description of what an item was about. |
| `section_title`, `section_kind` | The agenda section, matched on its text and never on its number, which renumbers between meeting formats. `section_kind` collapses it to consent, hearing, administrative, ceremonial, closed-session and so on. It is the closest thing the record has to a contestedness signal: an item passed in a consent batch of twenty is not the same act as a hearing item with public testimony. |
| `depth`, `parent_item_id` | The chapter nesting. Depth 0 is a plain numbered item, 1 a lettered child or an unnumbered entry. |
| `video_offset_seconds`, `end_offset_seconds` | Where the item starts and ends in the recording. An item ends at the next item of the same or shallower depth, not simply at the next row, so an item with children is not one second long. |
| `is_closed_session` | Taken from the clerk's own section label, never from how long the chapter ran. Every duration-based test mislabelled something real. |
| `issue_grouping_slug` | Present in the schema, unpopulated here. |

## `meetings.item_identifiers`

Ordinance, resolution, case, parcel and street-address values pulled out of the
clerk's agenda title. It exists so that a lookup for a specific ordinance
resolves by exact match, rather than by similarity, which would happily return
Ordinance 3956 for a search for Ordinance 3955.

| Field | Meaning |
| --- | --- |
| `id_type` | ordinance, resolution, case, apn or address. |
| `canonical_value` | The normalized form to match on. |
| `display_value` | How the clerk wrote it in the title. |

Only a minority of agenda items carry an identifier at all. Most of the record
is reachable only through the words in the title.

## `meetings.motions`

| Field | Meaning |
| --- | --- |
| `motion_id` | Primary key. |
| `meeting_id`, `agenda_item_id` | The meeting, and the item if the clerk filed the motion under one. `agenda_item_id` is nullable and NULL is a real state. |
| `motion_text`, `moved_by`, `seconded_by` | Verbatim clerk strings. These are the evidence. |
| `moved_by_person_id`, `seconded_by_person_id` | The resolved people. Derived, and rebuilt on each publish. |
| `motion_verb` | The verb matched against a known list, longest first. NULL on 68 motions where the clerk typed the recommendation where the verb goes. |
| `motion_class` | procedural or substantive, derived from the verb. USABLE, not certified: it is an editorial grouping, and it is the filter a published count needs. |
| `outcome` | approved or declined, as the clerk recorded it. |
| `structure_artifact_id` | The archived Granicus index (`artifact_kind = structure_json`) this motion was parsed from. A real foreign key into `artifacts`. |
| `panel_artifact_id` | The archived MetaViewer vote panel this motion's vote rows came from. NULL when no panel was served. |
| `panel_status` | `complete`: Granicus served the whole panel. `partial`: the panel came from an HTTP 500 body that stopped rendering at a recusal or abstention row, so the member set is one short and the cited artifact's `http_status` is 500. `none`: no panel was served; any vote rows on this motion were named by the minutes. |

## `meetings.votes`

| Field | Meaning |
| --- | --- |
| `vote_id` | Primary key. |
| `motion_id` | The motion. The table is unique on `(motion_id, member_name)`, so the clerk's label is the identity of the panel row. |
| `member_name` | The clerk's label at that meeting, such as "Councilmember Kalani" or "Mayor Kalani" for the same person before and after an installation. Always the clerk label, never a surname a document happened to print. |
| `vote_value` | aye, no, absent, abstain, recused, or NULL for recorded but not published. |
| `vote_value_source` | Which record supplied the value: `action_minutes`, `approved_minutes`, `transcript`, or NULL where none did. |
| `person_id` | The resolved member. |
| `source_artifact_id` | The archived document the value was read from, a foreign key into `artifacts`. Never NULL beside a non-NULL `vote_value`; the laptop refuses to publish a value that cites nothing. The artifact kind matches the source: `action_minutes` cites a `minutes_pdf`, `approved_minutes` an `approved_minutes_pdf`, `transcript` an `asr_envelope`. |

## `meetings.members`

Identity only, by design. No email, no phone, no address, no voter linkage.

| Field | Meaning |
| --- | --- |
| `person_id` | Primary key, stable across the corpus. |
| `canonical_name` | The person's name. Use this to follow a member across a change of office. |
| `clerk_labels` | Every label the clerk has used for them. |

## `meetings.seats`

The time-varying roster, with half-open bounds.

| Field | Meaning |
| --- | --- |
| `person_id`, `body_slug`, `role` | Who, which body, which office. |
| `valid_from`, `valid_to` | The window. **A NULL is not an unknown date.** NULL `valid_from` means the evidence window starts later than the seat did, never that the seat began on a date nobody knows. NULL `valid_to` means the seat was still held at the end of the window. |
| `source_ref` | The document the boundary was read off, usually the resolution that installed the officers. A seat closes at the first installation on or after its holder's last sighting and cites that one. |

Terms are staggered, so an installation seats some members and leaves the rest
mid-term. Being present after an installation is not evidence of having started
there, and a bound is claimed only where the record can see the change.

## `meetings.artifacts`

The provenance ledger. One row per source document, so any published row can be
traced to the bytes it was read from.

| Field | Meaning |
| --- | --- |
| `artifact_kind` | What kind of document: the meeting index, an agenda PDF, action or approved minutes, a vote panel. |
| `source_url`, `sha256`, `byte_size`, `content_type`, `http_status` | Where it came from and exactly what came back. The URL is part of the identity alongside the hash, because two URLs can return identical bytes. |
| `fetched_at` | When. |
| `superseded_by` | Points at the artifact that replaced this one. A source that changed between fetches becomes a new row with the old one marked, rather than a silent overwrite. |

Two kinds of row need a word. A `vote_panel_<id>` row with `http_status` 500 is
not a failed fetch: it is the partial panel Granicus returns when its renderer
crashes on a recusal row, archived with the status it came with, and the
motion that cites it carries `panel_status = 'partial'`. An `asr_envelope` row
has a `source_url` beginning `local:` rather than `https:`, because the
document is the maintainer's own transcription of the archived recording, not
something the city served; its sha256 is still the hash of the exact bytes a
`transcript` value was read from, and the recording it transcribes is the
`video_mp4` row for the same meeting.

The archived files themselves are not published. The ledger is, so a claim can
be checked against the city's own copy at the recorded URL.

## `meetings.publish_runs`

One row per applied publish, written inside the publish transaction, so a run
that rolled back leaves no claim that it happened.

| Field | Meaning |
| --- | --- |
| `run_id`, `started_at`, `finished_at` | When your copy was written. |
| `mode` | How the publisher was invoked. |
| `brake_tripped`, `force_reason` | Whether a safety check fired, and the reason recorded for overriding it. |
| `counts` | Per-table JSON of source, upserted and pruned row counts. All-zero upserts mean the run found nothing changed. |

## `meetings.v_votes`

Joins a vote to its motion, agenda item, meeting and body, plus the member the
vote resolves to, and every join is LEFT. A motion filed under no agenda item
and a vote whose label has not resolved to a person are both real states, and
an inner join would silently drop exactly the rows a reader is most likely
checking on. Carries `source_artifact_id` and `panel_status` through.

## `meetings.v_vote_sources`

One row per vote row, beside the three documents behind it, each as
`artifact_id`, `source_url`, `sha256` and (for the value source) `fetched_at`:

| Prefix | The document |
| --- | --- |
| `source_*` | What the value was read from: the minutes PDF or the ASR envelope. NULL beside a NULL `vote_value`, never beside a value. |
| `panel_*` | The MetaViewer vote panel the member list came from. `panel_http_status` is 500 for a partial panel. |
| `structure_*` | The Granicus index the motion was parsed from. |

Every join is LEFT, for the same reason as above.

There are no summary views. A pre-aggregated count would freeze one question's
shape, and a reader with SQL can ask their own.
