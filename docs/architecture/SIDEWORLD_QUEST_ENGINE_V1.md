# SIDEWORLD Quest Engine V1 — Architecture Blueprint

**Status:** PROPOSED / DESIGN ONLY  
**Date:** 2026-10-07  
**Base commit:** `3954929627c86cada3b7b4ed0233943f9a275b48`  
**Database changes in this document:** none

## 1. Purpose

Quest Engine V1 is the missing gameplay layer between the already deployed SIDEWORLD foundation
(`universe`, `geo`, `canon`) and the future player-facing SIDEWORLD application.

The engine must support:

- reusable real-world city/location knowledge;
- canonical universes, worlds, themes, franchises, series and characters;
- versioned quest authoring;
- ordered real-world stops;
- puzzles/challenges, private answer rules and hints;
- automated/editorial/field QA;
- immutable published content snapshots;
- guest or authenticated play runs;
- per-stop progress, answer attempts and gameplay events;
- later AI City Factory generation without coupling authoring data to the public API.

## 2. Verified current staging baseline

Read-only inspection of staging on 2026-10-07 confirms:

- no `quest`, `play` or `signal` schema exists;
- no existing quest/version/stop/challenge/hint/run/attempt tables exist in the repository default branch;
- `universe`, `geo` and `canon` V3.2 foundation exists on staging;
- all V3.2 authoring tables are private/RLS-enabled;
- `passport.journeys` and `passport.events` are existing OUTLAND World-journey objects and must not be repurposed as SIDEWORLD quest runtime tables.

Therefore V1 can be additive. It must not rename or alter existing OUTLAND operational entities.

## 3. Schema boundary

Use two new private schemas:

- `quest` — authored, versioned, publishable quest content;
- `play` — runtime player/group sessions and progression.

Do **not** use a `signal` schema for the core quest engine. SIGNAL is a gameplay/lore trigger and can later be represented as content/events without making it the ownership boundary for all quest data.

Both schemas remain private by default:
- RLS enabled on every table;
- no direct grants to `anon`, `authenticated` or `service_role` unless separately reviewed;
- not added to Supabase exposed schemas in the foundation migration;
- player access later goes through audited RPC/API contracts.

## 4. Core relationship

```text
universe.universes
    ├── universe.worlds
    ├── universe.themes
    └── canon.franchises
          ├── canon.series
          ├── canon.characters
          ├── canon.factions
          ├── canon.lore_facts
          └── canon.canon_rules

geo.countries
    └── geo.cities
          └── geo.locations
                └── geo.location_facts ── geo.fact_sources ── geo.sources

quest.quests
    └── quest.quest_versions
          ├── quest.stops ──> geo.locations
          │     └── quest.challenges
          │           ├── quest.answer_rules
          │           └── quest.hints
          ├── quest.version_characters ──> canon.characters
          ├── quest.version_lore_facts ──> canon.lore_facts
          └── quest.version_checks

play.runs ──> quest.quest_versions
    ├── play.run_stops ──> quest.stops
    ├── play.attempts ──> quest.challenges
    └── play.events
```

## 5. Authoring tables

### 5.1 `quest.quests`

Stable identity of a quest, independent of any particular published revision.

Recommended columns:

- `id uuid PK`
- `slug text NOT NULL`
- `city_id uuid NOT NULL -> geo.cities(id)`
- `world_id uuid NULL -> universe.worlds(id)`
- `theme_id uuid NULL -> universe.themes(id)`
- `series_id uuid NULL -> canon.series(id)`
- `name text NOT NULL`
- `summary text NULL`
- `status text NOT NULL DEFAULT 'draft'`
  - `draft | active | archived`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Constraints/indexes:

- unique `(city_id, slug)`;
- index city/world/theme/series/status;
- nonblank slug/name.

Notes:

- `city_id` is mandatory because every V1 quest is physically playable in one city.
- `world_id`, `theme_id` and `series_id` are optional so SIDEWORLD can support standalone quests.
- Do not duplicate `universe_id` or `franchise_id` here when they can be derived through canonical relationships.
- Cross-domain compatibility (for example series/universe matching world/universe) must be validated by publish checks before publication.

### 5.2 `quest.quest_versions`

Immutable content snapshot after publication.

Recommended columns:

- `id uuid PK`
- `quest_id uuid NOT NULL -> quest.quests(id) ON DELETE CASCADE`
- `version_no integer NOT NULL`
- `locale text NOT NULL`
- `status text NOT NULL DEFAULT 'draft'`
  - `draft`
  - `automated_checked`
  - `editorial_checked`
  - `field_verified`
  - `published`
  - `superseded`
  - `retired`
- `title text NOT NULL`
- `subtitle text NULL`
- `intro_text text NULL`
- `outro_text text NULL`
- `player_instructions text NULL`
- `difficulty text NULL`
- `estimated_duration_min integer NULL`
- `estimated_distance_m integer NULL`
- `canon_version integer NULL`
- `source_version_id uuid NULL -> quest.quest_versions(id)`
- `published_at timestamptz NULL`
- `superseded_at timestamptz NULL`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Constraints/indexes:

- unique `(quest_id, locale, version_no)`;
- partial unique index: one row with `status='published'` per `(quest_id, locale)`;
- positive version/duration/distance;
- `source_version_id <> id`.

Publication rule:

Published/superseded/retired versions are content-immutable. A new edit creates a new version. Only lifecycle fields needed to supersede/retire a version may change after publication.

### 5.3 `quest.stops`

Ordered physical/narrative stages of one quest version.

Recommended columns:

- `id uuid PK`
- `quest_version_id uuid NOT NULL -> quest.quest_versions(id) ON DELETE CASCADE`
- `sequence_no integer NOT NULL`
- `location_id uuid NULL -> geo.locations(id) ON DELETE RESTRICT`
- `stop_type text NOT NULL DEFAULT 'challenge'`
  - `challenge | narrative | checkpoint | finish`
- `title text NOT NULL`
- `arrival_text text NULL`
- `completion_text text NULL`
- `navigation_note text NULL`
- `safety_note text NULL`
- `arrival_radius_m integer NULL`
- `is_optional boolean NOT NULL DEFAULT false`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Constraints:

- unique `(quest_version_id, sequence_no)`;
- positive sequence;
- radius sensible range (for example 5–500 m);
- physical challenge/checkpoint stops normally require `location_id`; narrative-only stops may omit it.

A stop points to reusable `geo.locations`; it does not copy city POI truth.

### 5.4 `quest.challenges`

One stop can contain one or more ordered tasks.

Recommended columns:

- `id uuid PK`
- `stop_id uuid NOT NULL -> quest.stops(id) ON DELETE CASCADE`
- `sequence_no integer NOT NULL DEFAULT 1`
- `challenge_type text NOT NULL`
  - V1: `text_answer | number_answer | multiple_choice | observation | code`
- `prompt text NOT NULL`
- `instructions text NULL`
- `success_text text NULL`
- `failure_text text NULL`
- `is_required boolean NOT NULL DEFAULT true`
- `max_attempts integer NULL`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Constraints:

- unique `(stop_id, sequence_no)`;
- positive sequence/max_attempts;
- nonblank prompt/type.

Do not put canonical answers in this table because challenge payload may eventually be delivered to a client.

### 5.5 `quest.answer_rules`

Server-side answer validation. This table is private and is never returned directly to the player client.

Recommended columns:

- `id uuid PK`
- `challenge_id uuid NOT NULL -> quest.challenges(id) ON DELETE CASCADE`
- `rule_type text NOT NULL`
  - `normalized_exact | accepted_values | regex | numeric_range | option_id`
- `canonical_answer text NULL`
- `accepted_values jsonb NOT NULL DEFAULT '[]'`
- `config jsonb NOT NULL DEFAULT '{}'`
- `normalization_profile jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

V1 normalization should support at least:
- trim;
- case folding;
- Unicode normalization;
- configurable punctuation/diacritic handling;
- accepted aliases.

Answer correctness is evaluated server-side. Never ship `canonical_answer` or accepted answers in a public quest payload.

### 5.6 `quest.hints`

- `id uuid PK`
- `challenge_id uuid NOT NULL -> quest.challenges(id) ON DELETE CASCADE`
- `sequence_no integer NOT NULL`
- `hint_text text NOT NULL`
- `penalty_points integer NOT NULL DEFAULT 0`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Unique `(challenge_id, sequence_no)`.

### 5.7 `quest.version_characters`

Records which canonical characters are used by a quest version.

- `quest_version_id uuid -> quest.quest_versions`
- `character_id uuid -> canon.characters`
- `role text NOT NULL`
  - examples: `narrator | protagonist | antagonist | messenger | mentioned`
- `sort_order integer NOT NULL DEFAULT 100`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- composite PK `(quest_version_id, character_id, role)`

This is authoring/provenance metadata. Player-visible character dialogue remains snapshot content inside the quest version/stops, so later character edits cannot silently change an already published quest.

### 5.8 `quest.version_lore_facts`

Pins canon dependencies used or revealed by a quest version.

- `quest_version_id uuid -> quest.quest_versions`
- `lore_fact_id uuid -> canon.lore_facts`
- `usage_type text NOT NULL`
  - `premise | clue | reveal | background`
- `created_at`
- composite PK `(quest_version_id, lore_fact_id, usage_type)`

Useful for AI continuity checks and future cross-city story progression.

### 5.9 `quest.version_checks`

Auditable quality/publishing checks.

Recommended columns:

- `id uuid PK`
- `quest_version_id uuid NOT NULL -> quest.quest_versions`
- `check_stage text NOT NULL`
  - `automated | editorial | field`
- `check_type text NOT NULL`
- `outcome text NOT NULL`
  - `passed | failed | warning`
- `checked_by_profile_id uuid NULL -> shared.profiles(id)`
- `actor_type text NOT NULL DEFAULT 'human'`
  - `human | ai | system`
- `evidence jsonb NOT NULL DEFAULT '{}'`
- `notes text NULL`
- `checked_at timestamptz NOT NULL DEFAULT now()`

The quest version status is the workflow state; this table is the auditable evidence supporting that state.

## 6. Runtime tables

### 6.1 `play.runs`

A concrete play session against exactly one immutable quest version.

Recommended columns:

- `id uuid PK`
- `quest_version_id uuid NOT NULL -> quest.quest_versions(id) ON DELETE RESTRICT`
- `profile_id uuid NULL -> shared.profiles(id) ON DELETE SET NULL`
- `status text NOT NULL DEFAULT 'active'`
  - `active | completed | abandoned | expired`
- `started_at timestamptz NOT NULL DEFAULT now()`
- `completed_at timestamptz NULL`
- `last_activity_at timestamptz NOT NULL DEFAULT now()`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- `created_at`
- `updated_at`

Guest play is supported through an audited server/session layer later. Do not expose a raw writable `play.runs` table to anonymous clients.

A run always stays pinned to the version it started with even if a newer quest version is subsequently published.

### 6.2 `play.run_stops`

Materialized per-run progression.

- `run_id uuid NOT NULL -> play.runs(id) ON DELETE CASCADE`
- `stop_id uuid NOT NULL -> quest.stops(id) ON DELETE RESTRICT`
- `status text NOT NULL DEFAULT 'locked'`
  - `locked | available | active | completed | skipped`
- `opened_at timestamptz NULL`
- `completed_at timestamptz NULL`
- `hints_used integer NOT NULL DEFAULT 0`
- `metadata jsonb NOT NULL DEFAULT '{}'`
- PK `(run_id, stop_id)`

A server-side start-run operation should create the expected run-stop rows from the selected quest version.

### 6.3 `play.attempts`

Append-oriented answer attempts.

- `id uuid PK`
- `run_id uuid NOT NULL -> play.runs(id) ON DELETE CASCADE`
- `challenge_id uuid NOT NULL -> quest.challenges(id) ON DELETE RESTRICT`
- `answer_payload jsonb NOT NULL`
- `normalized_input text NULL`
- `is_correct boolean NOT NULL`
- `validation_result jsonb NOT NULL DEFAULT '{}'`
- `attempted_at timestamptz NOT NULL DEFAULT now()`

The validation result must never contain canonical answers or private answer-rule material.

### 6.4 `play.events`

Append-only gameplay/analytics event stream, separate from existing `passport.events`.

- `id bigint generated always as identity PK`
- `run_id uuid NOT NULL -> play.runs(id) ON DELETE CASCADE`
- `stop_id uuid NULL -> quest.stops(id) ON DELETE RESTRICT`
- `challenge_id uuid NULL -> quest.challenges(id) ON DELETE RESTRICT`
- `event_type text NOT NULL`
- `payload jsonb NOT NULL DEFAULT '{}'`
- `occurred_at timestamptz NOT NULL DEFAULT now()`

Initial event vocabulary:
- `run_started`
- `stop_opened`
- `hint_opened`
- `answer_submitted`
- `challenge_completed`
- `stop_completed`
- `stop_skipped`
- `run_completed`
- `run_abandoned`

## 7. Publishing workflow

Canonical V1 workflow:

```text
draft
  ↓
automated_checked
  ↓
editorial_checked
  ↓
field_verified
  ↓
published
  ↓
superseded / retired
```

Rules:

1. AI generation creates only `draft`.
2. Automated checks cannot mark content as field verified.
3. Editorial approval requires required automated checks to pass.
4. Field verification requires evidence for physical anchors, route/access/safety and answer observability.
5. Publication requires all mandatory stages to be satisfied.
6. Publishing version N+1 atomically marks version N `superseded` for the same quest+locale.
7. Runs already using version N continue on N.
8. Published content rows cannot be edited/deleted in place; changes create N+1.
9. Emergency disabling of a dangerous quest is a quest/publication availability action, not mutation of the historical content snapshot.

## 8. Required publication validation

Before `published`, server-side/DB validation must confirm at least:

- quest city exists and is active enough for use;
- every required physical stop belongs to the same city as the quest;
- all required stops have valid coordinates through `geo.locations`;
- no duplicate stop sequence;
- every required challenge has at least one private answer rule where needed;
- stop/challenge/hint order is valid;
- required geo facts used by clues are not disputed;
- route starts/ends coherently;
- duration/distance are plausible;
- safety/access flags have been reviewed;
- all referenced characters/lore are compatible with approved canon;
- required automated/editorial/field checks are passed.

Cross-domain consistency should be enforced at publish time rather than by duplicating universe/franchise IDs onto every row.

## 9. Security model

V1 authoring and runtime schemas remain private.

Later public/player API should be intentionally narrow, for example:

- `api.list_public_quests(city_slug, locale)`
- `api.get_quest_start(quest_slug, locale)`
- `api.start_run(...)`
- `api.get_current_stop(run_token)`
- `api.submit_answer(run_token, challenge_id, answer)`
- `api.open_hint(run_token, hint_id)`
- `api.reset_run(run_token)`

Important rules:

- never return `quest.answer_rules` to client code;
- answer validation is server-side;
- never let a client choose arbitrary next-stop state;
- only published quest versions are playable;
- run access uses authenticated ownership or a secure expiring guest capability;
- rate-limit answer submission;
- redact unnecessary raw answer data from analytics/long-term storage if privacy does not require it.

## 10. Why `play` is separate from `passport`

Existing `passport.journeys/events` represent OUTLAND World journeys and are already tied to `shared.worlds`.

SIDEWORLD quest play is a different domain:
- a quest run is tied to `quest.quest_versions`;
- one SIDEWORLD World can span multiple cities/quests;
- standalone quests may have no OUTLAND World;
- quest retries and answer attempts are gameplay telemetry, not Passport canon.

Later, completing a quest can emit a deliberately mapped Passport/discovery event, but the runtime truth remains in `play`.

## 11. V1 scope vs later scope

### Required now

- 9 authoring tables:
  - quests
  - quest_versions
  - stops
  - challenges
  - answer_rules
  - hints
  - version_characters
  - version_lore_facts
  - version_checks
- 4 runtime tables:
  - runs
  - run_stops
  - attempts
  - events
- publishing lifecycle;
- immutability guard;
- private-by-default RLS/grants;
- read-only structural tests;
- one golden test quest on staging.

### Later

- teams/group membership;
- scoring/leaderboards;
- achievements and collectibles;
- branching routes;
- multimedia assets;
- photo/vision validation;
- paid entitlements;
- bookings/partners;
- offline packs;
- creator marketplace;
- cross-quest inventory;
- richer Passport integration.

Do not block the first playable quest on these later features.

## 12. Migration plan

No migration is authorized by this design document.

Recommended additive implementation sequence after review:

1. `20261007xxxx_quest_authoring_foundation.sql`
   - schema `quest`
   - quests, quest_versions, stops, challenges, answer_rules, hints
2. `20261007xxxx_quest_canon_qa.sql`
   - version_characters, version_lore_facts, version_checks
   - publish/immutability validation functions/triggers
3. `20261007xxxx_play_runtime_foundation.sql`
   - schema `play`
   - runs, run_stops, attempts, events
4. tests:
   - structure/FKs
   - private-schema/RLS negative checks
   - immutable published version
   - cross-city stop rejection at publish
   - answer rule privacy
   - run pinned to immutable version
   - existing OUTLAND/Passport regression tests

Apply locally first, then staging. Production requires a separate explicit authorization after staging acceptance.

## 13. First golden quest

Use the existing Valletta prototype as the first technical golden quest because its route/puzzle behavior is already familiar.

It is test inventory, not automatically launch inventory.

The first end-to-end target:

```text
Valletta
  -> reusable geo.locations
  -> one draft quest
  -> one quest_version
  -> ordered stops
  -> challenge + answer rules + hints
  -> automated/editorial/field checks
  -> publish
  -> start run
  -> solve/skip/hint
  -> complete run
  -> analytics events
```

After the engine works end-to-end, commercial validation inventory should focus on Novi Sad, Belgrade and Dubai.
