# OUTLAND COMPASS — M2 Technical Architecture

**Version:** M2 / Foundation  
**Date:** 18 August 2026  
**Status:** implementation baseline

## 1. Decision

COMPASS v0.1 remains deliberately narrow: **Property Radar** is the first production module. M2 creates the durable technical foundation for M3–M8 without implementing WAYFINDER, SENSE, PASSPORT or MYSTERIES yet.

A key M1/M2 domain decision is now explicit:

**SIGNAL → CANDIDATE → SHORTLIST → DD → NEGOTIATION → ASSET**

A **Signal** is a discovered opportunity or listing that may be noisy or incomplete. A **Candidate** is a signal that has been promoted into the investment pipeline and is worth structured evaluation.

This prevents the serious candidate pipeline from becoming a dumping ground for every listing seen.

---

## 2. System boundaries

```text
┌─────────────────────────────────────────────────────────┐
│                    ANGULAR WEB APP                      │
│  Radar · Candidate · Compare · DD · Worlds             │
└──────────────────────────┬──────────────────────────────┘
                           │ Supabase JS
                           │ publishable key + user JWT
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     SUPABASE                            │
│                                                         │
│  Auth ─────┐                                             │
│            ▼                                             │
│  PostgreSQL + RLS  ◄──── Storage (private evidence)     │
│       │                                                   │
│       ├─ Signals / Candidates / Worlds                   │
│       ├─ Scoring / Confidence / Gates                    │
│       ├─ DD / Evidence / Documents / Visits              │
│       ├─ Decisions / Assets / Audit                      │
│       └─ Read models / views                             │
│                                                         │
│  Edge Functions                                          │
│       ├─ AI listing extraction (later M3/M4)             │
│       ├─ AI summary/scoring assist (later M4)            │
│       └─ privileged server integrations                  │
└─────────────────────────────────────────────────────────┘
```

### Client-side boundary

Angular may directly use the Supabase Data API for ordinary authenticated CRUD where RLS is sufficient.

The browser receives only:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

No secret/service key is ever placed in Angular code.

### Server-side boundary

Edge Functions are used only where the browser must **not** hold credentials or where a transaction/orchestration boundary is useful:

- LLM/API secrets,
- later listing extraction,
- external registry or mapping integrations requiring secrets,
- imports that require elevated validation,
- scheduled/background work later.

The Supabase secret key/service role is server-only and bypasses RLS, so use is deliberately narrow.

---

## 3. Environments

Use three levels:

1. **Local** — Supabase CLI + local Postgres; destructive reset allowed.
2. **Staging** — hosted Supabase project for integration/UAT and seed/demo data.
3. **Production** — hosted Supabase project containing real OUTLAND investment data.

Schema changes are never made manually in production as the source of truth.

Canonical flow:

```text
migration SQL in Git
      ↓
supabase start
      ↓
supabase migration up / db reset
      ↓
tests + Angular against local
      ↓
push to staging
      ↓
verify
      ↓
push same migrations to production
```

---

## 4. Repository structure

```text
outland-compass/
├─ apps/
│  └─ web/                         Angular application
│     ├─ src/app/core/
│     ├─ src/app/features/radar/
│     ├─ src/app/features/candidate/
│     ├─ src/app/features/compare/
│     ├─ src/app/features/dd/
│     ├─ src/app/features/worlds/
│     └─ src/app/shared/
├─ supabase/
│  ├─ migrations/
│  │  ├─ 202608180001_core_auth.sql
│  │  ├─ 202608180002_radar_schema.sql
│  │  ├─ 202608180003_scoring_views_functions.sql
│  │  └─ 202608180004_rls_storage_audit.sql
│  ├─ seed.sql
│  └─ functions/
├─ docs/
│  ├─ M2_TECHNICAL_ARCHITECTURE.md
│  └─ M1_UX_REFERENCE.png
└─ README.md
```

---

## 5. Data ownership and major entities

### Identity / permissions

- `profiles`
- `user_roles`

Roles:

- `OWNER`
- `ADMIN`
- `ANALYST`
- `ADVISOR`
- `VIEWER`

v0.1 may start with one real user, but permissions are multi-user from day one.

### Discovery

- `signals`

A Signal stores a raw discovered opportunity, source URL, source-provided data, AI extraction result and capture status.

### Investment pipeline

- `candidates`
- `candidate_sources`
- `candidate_price_history`
- `candidate_media`
- `candidate_economics`

A candidate is the durable investment object.

### World configuration

- `worlds`
- `score_dimensions`
- `world_dimension_weights`
- `world_score_criteria`
- `world_gate_definitions`

World configuration drives scoring and DD instead of hard-coding GREENHILL/RIVERKEEPER rules into Angular.

### Evaluation

- `evaluations`
- `evaluation_dimension_weights`
- `evaluation_items`

Every evaluation snapshots its scoring weights and criteria. This is important: changing a World profile later must **not rewrite history** or change an old 91 score into 87.

### Gates and DD

- `candidate_gates`
- `dd_items`
- `documents`
- `evidence_items`

`UNKNOWN` is first-class. It is never silently converted to score zero.

A critical Gate `FAIL` causes the candidate read model to become **BLOCKED**, independent of the weighted COMPASS score.

### Field work / decisions

- `notes`
- `visits`
- `decisions`
- `activities`

### Acquisition handoff

- `assets`

When a candidate is acquired, the candidate remains intact. It is linked to an `asset`, creating continuity for later COMPASS Development / Operations modules.

---

## 6. Scoring model

Default dimension weights:

| Dimension | Weight |
|---|---:|
| PLACE | 35% |
| FEASIBILITY | 20% |
| ECONOMICS | 20% |
| OUTLAND | 15% |
| NETWORK | 10% |

Each world can override weights.

### Item score

Each criterion has:

- `score`: 0–100 or `NULL`
- `confidence_percent`: 0–100
- `evidence_state`: UNKNOWN / CLAIMED / OBSERVED / VERIFIED
- `item_weight`

### Dimension score

Only scored items participate in the dimension score denominator.

```text
dimension_score =
Σ(score × item_weight)
────────────────────────
Σ(item_weight for scored items)
```

### Confidence

All required criteria remain in the confidence denominator.

```text
dimension_confidence =
Σ(confidence × item_weight)
──────────────────────────
Σ(all item weights)
```

Therefore an unknown criterion:

- does **not** behave as score 0;
- does reduce confidence.

### Overall COMPASS score

Only dimensions with a usable score participate in the score denominator.

Confidence remains weighted across all configured dimensions.

This produces the intended UI semantics:

**COMPASS 91 / Confidence 54%**

---

## 7. Gates

Gate state:

- `UNKNOWN`
- `PASS`
- `FAIL`
- `NOT_APPLICABLE`

A `world_gate_definition` can be marked `is_critical=true`.

Radar read model logic:

```text
if critical FAIL exists:
    recommendation = BLOCKED
else if score >= 90:
    recommendation = HOT
else if score >= 80:
    recommendation = STRONG
else if score >= 70:
    recommendation = WATCH
else:
    recommendation = LOW
```

RIVERKEEPER gets a separate gate template covering legal berth/location control, registration/registrability, commercial use, water envelope, shore/emergency access and wastewater.

---

## 8. Evidence model

Evidence must distinguish source quality.

Supported verification states:

- `UNVERIFIED`
- `PARTIALLY_VERIFIED`
- `VERIFIED`
- `DISPUTED`

Supported evidence types include:

- listing/seller statement
- document
- registry result
- professional opinion
- photo
- site visit
- map
- external URL
- other

Seller/listing claims may be stored but must remain visibly unverified.

Evidence can attach to:

- a candidate generally,
- a Gate,
- a DD item,
- an evaluation item.

Documents are stored in the private `compass-evidence` Supabase Storage bucket. PostgreSQL stores document metadata and references, never raw file bytes.

---

## 9. Security model

### Browser

The Angular client uses the Supabase publishable key and an authenticated user JWT.

### RLS

All application tables have RLS enabled.

High-level access:

| Role | Read | Candidate/evaluation write | Notes/evidence | World config | Roles/admin |
|---|---|---|---|---|---|
| OWNER | yes | yes | yes | yes | yes |
| ADMIN | yes | yes | yes | yes | yes |
| ANALYST | yes | yes | yes | no | no |
| ADVISOR | yes | no | yes | no | no |
| VIEWER | yes | no | no | no | no |

### Storage

`compass-evidence` is private.

- all application roles may read;
- OWNER / ADMIN / ANALYST / ADVISOR may upload;
- only OWNER / ADMIN / ANALYST may replace/delete files.

### Secrets

AI and third-party API secrets live only in Edge Function secrets / server configuration.

---

## 10. Angular architecture

Use standalone Angular features and route-level lazy loading.

Suggested feature boundaries:

```text
core/
  auth/
  supabase/
  guards/
  layout/
  models/

features/
  radar/
  candidate/
  compare/
  due-diligence/
  worlds/

shared/
  ui/
  score/
  gates/
  evidence/
  formatting/
```

Rules:

- no direct Supabase calls from presentation components;
- feature repositories/services own data access;
- domain types generated from the database schema;
- server-computed/read-view scores are displayed, not recomputed independently in Angular;
- business status transitions go through explicit service methods/RPCs, not arbitrary row patching.

---

## 11. Important transactions / RPC boundaries

### `start_evaluation(candidate_id)`

Creates a new versioned evaluation and snapshots:

- current world dimension weights;
- current world scoring criteria.

Old evaluations can never change because a World profile later changes.

### `initialize_candidate_gates(candidate_id)`

Copies the candidate's World gate template into candidate-specific gate rows.

### `promote_signal_to_candidate(signal_id, world_id)`

Creates the candidate, preserves source data, creates initial source and initial price-history entry, then links the Signal to the new Candidate.

### Acquisition

The first implementation can create `assets` through an application transaction/RPC after the Decision is `ACQUIRE`. It must never delete the candidate.

---

## 12. Read models

Angular Radar should read from database views rather than joining 15 tables in the browser.

Required read models:

- `v_evaluation_dimension_scores`
- `v_evaluation_scores`
- `v_candidate_gate_summary`
- `v_candidate_latest_evaluation`
- `v_candidate_radar`

`v_candidate_radar` contains:

- core candidate fields;
- asking price / €/m²;
- current phase-1 capital;
- latest COMPASS score;
- confidence;
- recommendation;
- critical failed/unknown gate counts;
- latest evaluation id.

---

## 13. M2 acceptance gate

M2 is complete when:

- local Supabase can reset from zero using committed migrations;
- staging can be created from the same migrations;
- Auth works;
- first user can be assigned OWNER;
- the six current Worlds are seeded;
- GREENHILL and RIVERKEEPER have different gate templates;
- `+ ADD SIGNAL` can be implemented against a real `signals` table;
- a Signal can be promoted to Candidate;
- evaluation snapshot tables exist;
- the score views demonstrate UNKNOWN ≠ 0 and lower confidence;
- a critical Gate FAIL yields BLOCKED in `v_candidate_radar`;
- private evidence Storage has RLS;
- production requires no schema edits through the dashboard.

---

## 14. Explicitly deferred

M2 does not implement:

- automatic listing crawlers;
- background monitoring;
- AI scoring automation;
- map/geocoding provider coupling;
- booking/revenue functionality;
- WAYFINDER;
- SENSE;
- PASSPORT;
- MYSTERIES.

The schema deliberately leaves a clean `assets` handoff so these can be added without replacing the Property Radar foundation.
