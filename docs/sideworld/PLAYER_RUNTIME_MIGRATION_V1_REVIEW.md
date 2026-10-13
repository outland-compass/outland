# SIDEWORLD Player Runtime V1 — migration review and rollback

**Status:** Proposed only. Not applied to production/staging, not approved for merge or release. Tracking: [OUTLAND #69](https://github.com/outland-compass/outland/issues/69), [Player #12](https://github.com/outland-compass/sideworld_app/issues/12).

## Read-only evidence, 2026-10-13

- Audited actual production (`huzcukdovavejejwohey`) and staging (`clgpxvyflycudzhdzjlv`) schema inventories, grants/RLS/functions and OUTLAND migrations `202610060004_sideworld_canon_foundation.sql`, `20261012151318_sideworld_quest_drafts_v1.sql` and `20260913141314_universe_v0_core_and_passport_journey.sql`.
- Existing `canon.quest_drafts` / `canon.quest_draft_revisions` are Studio-owned and RLS-enabled; their full latest-draft RPC is service-role-only and includes hidden answers and future content. They are not published content.
- No dedicated immutable playable release or Player progress store exists in inspected schemas. Existing `passport.journeys` / `passport.events` represent OUTLAND World-profile travel, not puzzle session state.
- Canonical `universe.universes`, `canon.franchises`, `canon.series`, `geo.cities` exist; this migration creates no duplicate registry. `canon.quest_draft_revisions` already has primary key (`draft_id,revision`).
- Player `lib/gameplay` and coordinator ports exist on main, but there is no real authorized online gameplay. Existing private editorial login requires OWNER/ADMIN and must NOT be reused to give regular testers admin privileges.
- Production and staging migration timestamps differ for some same-name Oct 2026 migrations. Reconcile their actual contents before any staging rehearsal.
- **Production backup availability and successful isolated restore readiness have NOT been verified.** Do not apply a production migration without that gate.

## Proposed additive structure

| Relation | Why it exists |
| --- | --- |
| `canon.quest_releases` | One versioned, frozen copy of an existing draft revision. Opaque UUID release ID; source document and engine hash immutable. `private_qa`, `published`, `retired` visibility; publication requires editorial, field and media approvals. Contains private answer keys; never browser-readable. |
| `player.qa_access` | Expiring, revocable actor/release tester entitlement distinct from Studio OWNER/ADMIN. |
| `player.quest_runs` | Trusted actor-owned version-bound progress, sequence and private engine event history, not an OUTLAND Passport journey. |
| `player.run_receipts` | Bounded, transactional idempotency receipt for the 16 most recent commands per run; prevents double-unlock and duplicate progression. |

New `public.sideworld_player_*` RPC functions are **service-role-only** (full content fetch, start, run read, actor-scoped receipt read, atomic compare-and-save). Table RLS is ON with no client policies and no direct role grants. A non-exposed `player.can_use_release_v1` helper enforces active QA grants or approved published visibility.

The migration creates **zero releases, zero QA grants and zero runs**. It deliberately does **not** add a publish/approve, grant/revoke or reset API. That follow-on layer must be authorized separately. Do not consider this migration alone sufficient to make a quest playable.

### Trust boundary — important

The database RPC accepts actorId and private next-progress state only from a **trusted Player server** using a privileged credential. The server must verify Supabase Auth JWT, derive actorId (never trust it from browser JSON), select an explicitly authorized immutable release, execute the TypeScript gameplay engine, and submit only a validated transition. The RPC provides atomicity/idempotency but **does not validate game answers or independently authenticate a JWT**. A leaked service-role credential has broad blast radius. Evaluate a narrowly scoped service gateway before public launch.

The `engine_content_hash` is a deterministic engine binding computed from the validated TypeScript input `{questId: sourceDraftId, revision: sourceRevision, document}`; it is **not a cryptographic signature** or a PostgreSQL-recomputed value. The release-trigger enforces JSONB equality with the originating Studio revision on insert; no mutation of content/source/hash after creation.

For `run_apply`, a row-level `FOR UPDATE` lock serializes commands. Existing receipt with same UUID and fingerprint returns the saved result; a different fingerprint conflicts. New commands must match the latest sequence and append exactly one event with unchanged version/hash. The update and receipt insert/prune are one transaction. Missing/expired QA grant denies even on resume. Retention: 16 receipts/run, 256 KiB maximum progress per snapshot; older retry IDs return safe stale conflicts, not double-advance.

### Limits explicitly deferred

- Storing a progress event history in every receipt is acceptable for private MVP **only** with bounds. Revisit data growth, replay cost, retention and event compaction before multi-city scale.
- `quest_runs.status` is initially `in_progress`; completion/abandon and reset must have future trusted, engine-validated RPC logic.
- User experience, public catalog, browser session, source/media licensing, verified physical stops and payment entitlements are not implemented.
- Actual PostgreSQL 17 execution, distributed concurrency, authorization negative tests, backup/restore, live seven-scene gameplay and field QA are **not verified by creating this PR**. Repository CI is not DB integration proof.

## Mandatory checks before considering database application

- [ ] Compare exact current production/staging migration contents and dependent deployed app contracts.
- [ ] Parse and execute on disposable PostgreSQL 17 (or approved staging only after migration reconciliation). Do NOT use production SQL for a parse test.
- [ ] Run `supabase/tests/verify-sideworld-player-runtime.sql` on the isolated migrated database, and test RPC calls with `anon`, `authenticated`, and `service_role` identities.
- [ ] Provision temporary *synthetic* Studio draft/release/QA actors in isolated DB. Test expiry/revocation, scope and version binding, content drift, unauthorized actor access and independent tester privileges.
- [ ] Race two real PostgreSQL connections against a single run/sequence, then verify exactly one commit. Test duplicate same/different request fingerprints, retry after additional commands and rollback on injected failure.
- [ ] Validate the exact seven-scene Studio V2 document privately only after authorized snapshot is created. Never send raw `answerKey` or progress history to a browser.
- [ ] Verify a fresh production backup and **successful isolated restore readiness**.
- [ ] GitHub PR and automated checks must pass. Obtain explicit founder approval of the exact SQL, backup/restore evidence and deployment window before any production migration. High-risk RLS/auth changes warrant staging rehearsal; staging otherwise remains optional.

## Rollback / abort plan (manual; no execution)

1. **Before any apply:** simply close the unmerged PR; no database changes exist.
2. **After a zero-data isolated apply:** disable gameplay flags, drain requests and confirm all new tables contain **zero** user data. Revoke the new service RPCs; drop the four new public RPCs, the private helper, then the new tables in dependency order: `player.run_receipts`, `player.quest_runs`, `player.qa_access`, `canon.quest_releases`. Drop the newly added release guard function and the `player` schema only if empty. Do not use `CASCADE`; do not touch `canon.quest_drafts`, `canon.quest_draft_revisions`, canonical universes or Passport.
3. **If any releases, grants or runs exist:** **do not drop tables**. Disable the feature and apply a reviewed forward fix after exporting/preserving data. Restore only from a verified recovery point with explicit authorization.

**Verified vs proposed:** The audit of existing models/RLS is verified by read-only tools. New table definitions, service RPCs and rollback are proposals pending SQL execution, concurrency/security tests and approval.
