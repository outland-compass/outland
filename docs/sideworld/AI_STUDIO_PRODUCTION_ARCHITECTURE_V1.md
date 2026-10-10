# SIDEWORLD AI Studio — Production Architecture V1

**Status:** Proposed implementation contract. Existing Canon Context Builder, City Knowledge read model and Quest Production preflight are implemented foundations; the creative generation modules below are **not implemented**. This document introduces no database changes.

## Scope and existing pipeline

Preserve the established AI City Factory sequence:
1. City intelligence
2. Route design
3. Story generation
4. Puzzle generation
5. Automated validation
6. Editorial review
7. Field QA
8. Publish & observe

Every generated stop needs a real physical anchor and coordinates. Opening hours and access restrictions require current evidence. Generation does not equal field verification. Preserve auditable content statuses: `draft`, `automated_checked`, `editorial_checked`, `field_verified`, `published`.

## Reusable input assets

### Franchise Creative Bible (proposed)

One canonical universe reference, one franchise identity, optional series, recurring characters and factions, themes, lore, tone, forbidden claims and visual style constraints. **Never create another universe registry.** The existing approved Canon Context Builder is the starting source of truth. Proposed lore enters only through explicit opt-in.

**Character Bible**: canonical character ID, franchise association, personality, motives, speech style, narrative role, relationships, prohibited portrayals, approved reference assets and visual constraints. Existing character canon records must be inspected before deciding which fields belong in tables and which belong in versioned asset metadata.

**Character Visual Identity**: AI-generated candidates are provisional. Human approval selects a versioned canonical design (portrait, full-body/reference sheet where needed, visual prompt recipe, asset provenance, usage rights and consistency constraints). Subsequent art generations reference approved design assets; do not regenerate the character identity independently for each city.

### City Intelligence (existing foundation)

Use existing city IDs, location IDs, fact/source relationships and verification status. A location is a real-world anchor; a fact is a claim supported by evidence. Keep fictional lore distinct from geographic truth. Partners/businesses, accommodation `base`, and collectible gameplay objects are separate concepts.

### Puzzle Mechanics Library (proposed)

Versioned mechanics independent of city and franchise, for example:
- `observation`: answer from a stable, publicly observable feature.
- `deduction`: infer from two or more supported observations.
- `sequence`: arrange observable facts in a supported order.
- `cipher`: decode using an explicitly supplied key and accessible clue.
- `navigation`: navigate between safe, public physical anchors.
- `dialogue`: fictional conversation based on approved character canon.

Each mechanic contract includes: `mechanicId`, `version`, `inputRequirements`, `playerInteraction`, `answerValidationMode`, `hintStrategy`, `accessibilityFallback`, `safetyConstraints`, `estimatedMinutes` and `automatedChecks`. Library templates do not contain invented city facts.

## Generation orchestration

A single `ProductionJob` is pinned to immutable input references: universe, franchise/canon context version, city knowledge snapshot, route constraints, puzzle library versions, locale and model/prompt version. Jobs should be reproducible at the input level; AI outputs are not assumed bit-for-bit deterministic.

```text
Canonical Context + Verified City Knowledge
                |
        Route candidate(s)
                |
      Story + character roles
                |
   Puzzle candidates per location
                |
   Deterministic validation + AI QA
                |
      Editorial review queue
                |
       On-location field QA
                |
    Versioned published quest
                |
       Quest Runtime / Player
```

Each stage emits structured output, provenance, warnings and review state. Failures must not silently auto-publish. Retrying a stage must not create duplicate published quests. Track token/asset-generation costs and elapsed time per stage to support the 1,000-city **target**, not forecast.

## Puzzle output contract (proposed)

```json
{
  "mechanicId": "observation",
  "mechanicVersion": 1,
  "locationId": "existing-location-uuid",
  "factIds": ["existing-fact-uuid"],
  "characterIds": [],
  "prompt": "Player-visible puzzle text",
  "acceptedAnswers": ["normalized-answer"],
  "answerNormalization": "case-fold-trim",
  "hints": ["gentle clue", "stronger clue"],
  "fallback": "accessible alternate clue",
  "estimatedMinutes": 5,
  "verification": {
    "sourceIds": ["existing-source-uuid"],
    "automatedStatus": "pending",
    "editorialStatus": "pending",
    "fieldStatus": "pending"
  }
}
```

This is an **authoring-only** contract. Accepted answers must not be included in a public player payload before server-side answer checking. Puzzle candidates cannot be published based solely on model confidence.

## Validation gates

- Canonical universe ownership and franchise/character associations match the selected context.
- Location/fact/source IDs exist and reference the selected city where applicable.
- The physical clue is publicly observable, with no private-property access requirement.
- Answer is unambiguous, tolerant to expected spelling variants and independently tested.
- Hints progress from subtle to explicit without revealing unintended secrets.
- Accessibility alternative and emergency skip exist; route safety is reviewed.
- Character dialogue obeys approved canon and visual assets use approved reference versions.
- Duplicate and near-duplicate puzzles are flagged across a city and franchise.
- Human editorial and field QA are auditable before public publication.

## Proposed next implementation slices

1. **Read-only production input manifest:** compile selected Canon Context + City Knowledge into one validated, versioned JSON preview; expose missing prerequisites.
2. **Puzzle mechanic registry in code:** typed, versioned, testable templates without database migrations.
3. **Candidate generator behind a disabled-by-default flag:** structured output, schema validation and cost controls; no publishing.
4. **Editorial review UI:** approve/reject candidate puzzles and character asset variants.
5. **Quest Composer and versioned publishing:** only after auditing production schema, migrations, RLS, current apps and rollback strategy.

## Explicit non-goals for this milestone

No production database changes; no new universe table; no unreviewed AI publishing; no assumption that image generation, AI puzzle generation, job queues or mobile runtime already work.
