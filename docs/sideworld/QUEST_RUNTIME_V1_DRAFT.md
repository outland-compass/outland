# SIDEWORLD Quest Runtime V1 — Implementation Contract (Draft)

Status: **PROPOSAL / NOT YET IMPLEMENTED**. This is a contract for parallel Studio + mobile-player development, not a claim about the live database. No production or staging schema change is authorized by this document.

## Vertical slice

Create a 5–8 stop Novi Sad walking quest in Studio, publish a version, and play it on mobile. AI can propose draft content; a human reviews locations, answers and safety before publication. A quest belongs to one canonical universe; OUTLAND is one possible universe, not the parent platform.

## Canonical responsibilities

- `universe`: reference the **existing single canonical registry**; do not duplicate it in a new schema.
- `city`: shared geographical identity, not a universe-specific copy.
- `world`: optional universe-scoped experience context; not accommodation.
- `base`: accommodation/capacity only, separate from partners and discoveries.
- `quest`: mutable authoring identity, tied to city and universe, optionally world/theme.
- `quest_version`: immutable published snapshot with a stable version identifier.
- `quest_run`: one player's play session; progress is separate from published content.

**Do not create any of these tables until the existing production schema, migrations, applications, dependencies and RLS are audited.** Names above are conceptual until reconciled against the live schema.

## Proposed portable content contract (JSON, V1)

```json
{
  "schemaVersion": 1,
  "questId": "uuid",
  "version": 1,
  "universeId": "uuid",
  "cityId": "uuid",
  "worldId": null,
  "themeId": null,
  "locale": "sr-RS",
  "title": "Novi Sad: Follow the Signal",
  "intro": "A short opening narrative",
  "estimatedMinutes": 90,
  "stops": [
    {
      "id": "stable-stop-id",
      "order": 1,
      "locationId": "uuid",
      "latitude": 45.0,
      "longitude": 19.0,
      "arrivalRadiusMeters": 60,
      "narrative": "Story shown at the stop",
      "question": "A locally verifiable question",
      "answer": { "kind": "text", "accepted": ["example"] },
      "hints": ["First hint", "Second hint"],
      "safetyNote": "Use public pedestrian access"
    }
  ]
}
```

Coordinates above are placeholders, **not** verified Novi Sad stops. The contract should be validated before publication; do not rely on client-provided `universeId` for authorization.

## Minimum player state machine

`not_started → active → completed`; `active → paused → active`. Each stop progresses `locked → available → solved`. Store run progress independently of immutable quest version. Replaying starts a new run; reset does not mutate published content.

## API boundary (proposed, not implemented)

- Studio: create/edit draft, validate, publish immutable version, preview published version.
- Player: list published quests, fetch one published snapshot, start/resume run, submit answer, request hint, complete run.
- Server: verify player entitlement and universe boundaries; rate-limit answers; avoid leaking accepted answers to the browser before verification.
- GPS: advisory presence check with an accessibility/manual fallback; never rely on GPS alone for authorization or player safety.

## Publication gates

1. Universe/city/world/theme references are consistent with canonical ownership.
2. All stop IDs and ordering are stable and unique; location coordinates are valid.
3. At least 5 stops for the first field-test quest; every stop has a tested answer and hint.
4. Pedestrian routing and access verified on location; unsafe crossings, private access and inaccessible hours flagged.
5. AI-generated claims and local facts carry source/verification status; human review before public release.
6. A published version is immutable; later edits produce a new version.

## Delivery sequence

1. **Read-only audit**: reconcile current migrations, canonical tables, existing gameplay code, dependencies and RLS with this contract.
2. **Schema decision**: produce additive migration + rollback plan, avoid duplicated universe/city identities.
3. **Studio vertical slice**: author one quest with 5–8 stops and preview it.
4. **Mobile web player**: GPS/map, riddle, hints, progress, reset, finish; reuse same versioned payload.
5. **AI draft generation**: generate structured candidate quests, validate and route to human review.
6. **Staging E2E + field QA** in Novi Sad; only then consider production deployment after explicit approval for DB changes.

## Acceptance test

Given a reviewed quest draft, an authorized editor can publish version 1. A player can open it on a phone, solve every stop, resume progress after reload and finish. Updating the draft cannot alter an ongoing run pinned to version 1. Attempts to read private universe content or write another universe's quest are rejected.
