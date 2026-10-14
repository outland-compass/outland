# SIDEWORLD Player Runtime V1 — migration review and rollback

**Status:** Proposed only. Not applied to production/staging, not approved for merge or release. Tracking: [OUTLAND #69](https://github.com/outland-compass/outland/issues/69), [Player #12](https://github.com/outland-compass/sideworld_app/issues/12).

## Read-only evidence, 2026-10-13

- Audited actual production (`huzcukdovavejejwohey`) and staging (`clgpxvyflycudzhdzjlv`) schema inventories, grants/RLS/functions and OUTLAND migrations `202610060004_sideworld_canon_foundation.sql`, `20261012151318_sideworld_quest_drafts_v1.sql` and `20260913141314_universe_v0_core_and_passport_journey.sql`.
- Existing `canon.quest_drafts` / `canon.quest_draft_revisions` are Studio-owned and RLS-enabled; their full latest-draft RPC is service-role-only and includes hidden answers and future content. They are not published content.
- No dedicated immutable playable release or Player progress store exists in inspected schemas. Existing `passport.journeys` / `passport.events` represent OUTLAND World-profile travel, not puzzle session state.
- Canonical `universe.universes`, `canon.franchises`, `canon.series`, `geo.cities` exist; this migration creates no duplicate registry. `canon.quest_draft_revisions` already has primary key (`draft_id,revision`).
- Player main now contains the generic engine, server-owned RPC adapter, separate QA identity, gated HTTP API and mobile renderer (merged Player PRs #15/#18/#19). Live gameplay remains OFF. Existing Studio editorial login requires OWNER/ADMIN; ordinary testers must never inherit that role.
- Production and staging migration timestamps differ for some same-name Oct 2026 migrations. Reconcile their actual contents before any staging rehearsal.
- **Production backup availability and successful isolated restore readiness have NOT been verified.** Do not apply a production migration without that gate.

## Proposed additive structure

| Relation | Why it exists |
| --- | --- |
| `canon.quest_releases` | One versioned, frozen copy of an existing draft revision. Opaque UUID release ID; source document and engine hash immutable. `private_qa`, `published`, `retired` visibility; publication requires editorial, field and media approvals. Contains private answer keys; never browser-readable. |
| `player.qa_access` | Expiring, revocable actor/release tester entitlement distinct from Studio OWNER/ADMIN. |
| `player.quest_runs` | Trusted actor-owned version-bound progress, sequence and private engine event history, not an OUTLAND Passport journey. |
| `player.run_receipts` | Bounded, transactional idempotency receipt for the 16 most recent commands per run; prevents double-unlock and duplicate progression. |

Eight proposed `public.sideworld_player_*` RPC functions are **service-role-only**: five runtime functions (release read, start, run read, receipt read, atomic compare-and-save) plus three private QA operations (release create, grant, revoke). Table RLS is ON with no client policies and no direct role grants. Internal helpers enforce QA eligibility and Studio operator roles.

The migration creates **zero releases, zero QA grants and zero runs**. It now proposes narrowly authorized create/grant/revoke RPCs **for private QA only**; it does **not** include a public publish/approve, reset API, Studio admin HTTP workflow or automatic tester invitation. An authenticated Studio server route must derive the operator UUID from verified Auth, check OWNER/ADMIN and call the privileged RPC with explicit operator approval. The SQL also checks `shared.user_roles`. The new Player-only manifest helper (Draft PR #20) computes the actual engine hash; it performs no writes. Do not treat this migration alone as an invitation to play.

### Trust boundary — important

The database RPC accepts actorId and private next-progress state only from a **trusted Player server** using a privileged credential. The server must verify Supabase Auth JWT, derive actorId (never trust it from browser JSON), select an explicitly authorized immutable release, execute the TypeScript gameplay engine, and submit only a validated transition. The RPC provides atomicity/idempotency but **does not validate game answers or independently authenticate a JWT**. A leaked service-role credential has broad blast radius. Evaluate a narrowly scoped service gateway before public launch.

The `engine_content_hash` is a deterministic engine binding computed from the validated TypeScript input `{questId: sourceDraftId, revision: sourceRevision, document}`; it is **not a cryptographic signature** or a PostgreSQL-recomputed value. The release-trigger enforces JSONB equality with the originating Studio revision on insert; no mutation of content/source/hash after creation.

For `run_apply`, a row-level `FOR UPDATE` lock serializes commands. Existing receipt with same UUID and fingerprint returns the saved result; a different fingerprint conflicts. New commands must match the latest sequence and append exactly one event with unchanged version/hash. The update and receipt insert/prune are one transaction. Missing/expired QA grant denies even on resume. Retention: 16 receipts/run, 256 KiB maximum progress per snapshot; older retry IDs return safe stale conflicts, not double-advance.

### Limits explicitly deferred

- Storing a progress event history in every receipt is acceptable for private MVP **only** with bounds. Revisit data growth, replay cost, retention and event compaction before multi-city scale.
- `quest_runs.status` is initially `in_progress`; completion/abandon and reset must have future trusted, engine-validated RPC logic.
- User experience, public catalog, browser session, source/media licensing, verified physical stops and payment entitlements are not implemented.
- Earlier iterations of Draft PR #70 passed disposable PostgreSQL 17 schema replay, rollback-only functional SQL, client-role denials and two-connection CAS testing in GitHub Database CI. **The newly added QA operator RPCs must pass CI at their own final head before approval.** Real production/staging backup+restore, live authorization/provider execution, the seven-scene live quest and field QA are still unverified.

## Mandatory checks before considering database application

- [ ] Compare exact current production/staging migration contents and dependent deployed app contracts.
- [x] Previous migration version executed in disposable PostgreSQL 17 CI (four replay paths). **Re-run/verify all checks at this updated PR head.** Do NOT use production SQL for a parse test.
- [ ] Run `supabase/tests/verify-sideworld-player-runtime.sql` on the isolated migrated database, and test RPC calls with `anon`, `authenticated`, and `service_role` identities.
- [x] Previous version tested synthetic Studio draft/release/QA actors, revocation and authorization in disposable DB; updated PR additionally tests admin-only QA release creation and grant/revoke, **pending final-head CI**.
- [x] Prior head: two independent PostgreSQL sessions raced one run/sequence and passed one-write CAS test. Receipt replay and stale/conflicting commands passed transactional fixture. **Final-head CI and fault-injection edge cases remain review items.**
- [ ] Validate the exact seven-scene Studio V2 document privately only after authorized snapshot is created. Never send raw `answerKey` or progress history to a browser.
- [ ] Verify a fresh production backup and **successful isolated restore readiness**.
- [ ] GitHub PR and automated checks must pass. Obtain explicit founder approval of the exact SQL, backup/restore evidence and deployment window before any production migration. High-risk RLS/auth changes warrant staging rehearsal; staging otherwise remains optional.


## Private QA operator workflow — proposal only

1. An authenticated **Studio OWNER/ADMIN** explicitly chooses a stored `draft_id` and exact revision, reads the complete authoring document from a trusted server-only path, and checks editorial diagnostics. Never trust an actor UUID or authoring document submitted by the browser.
2. The Player's server-only `preparePrivateQaRelease` calculates `engineContentHash` with the actual generic engine and emits an **answer-free** manifest. It is not an approval, signature, publication or database update.
3. A privileged Studio server calls `sideworld_player_qa_release_create_v1(operator,draft,revision,hash)`. The proposed database function separately confirms `shared.user_roles` OWNER/ADMIN, frozen exact Studio revision, `draft` status, no error diagnostics and private QA visibility. Idempotent repetition returns the same release; any checksum mismatch conflicts.
4. A privileged operator calls `sideworld_player_qa_grant_v1(operator,release,tester,expires_at)`, only for existing Supabase Auth users, with 5-minute minimum and 14-day maximum expiry. Testers do not receive Studio admin privileges. `sideworld_player_qa_revoke_v1` revokes access immediately at the release entitlement check; a conscious future re-grant can reactivate it.
5. The Player loader **independently** validates the release content and recomputes the hash before game start, resume or action; neither the manifest nor Studio admin credentials reach the browser.

The RPCs alone are insufficient for production: **no authenticated operator HTTP action, audit log, approval UX or rate limiter is wired**. Create those behind default-OFF Studio flags in a separate code PR and test before allowing real access. Do not auto-mark any source, field or media as approved.

## Backup and restore evidence — mandatory operational gate

The connected Supabase tools exposed production/staging project health, schemas and migration inventory but **do not expose verifiable backup snapshots or restore success**. Project subscription tier is also unconfirmed.

Current Supabase [Database Backups](https://supabase.com/docs/guides/platform/backups) guidance: daily managed backups are available on paid plans; Free projects should maintain external logical dumps through `supabase db dump`. See [Backup/Restore CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) for role, schema and data export/restore instructions.

**Operator evidence required before applying PR #70:** identify the actual plan and available backup timestamp or create a fresh encrypted off-site logical dump. Preserve `auth`, migration history, Vault/encryption requirements, relevant non-database Storage objects, and any custom roles/triggers. Restore into an isolated disposable environment, test expected critical tables, functions and representative records, record timestamp/checksum and who verified the restore. An untested file or a green migration replay is **not** restore readiness. Never put credentials or customer data into GitHub/CI artifacts or public logs. Staging migration drift must be reconciled separately.

Do not restore **over** the production database as a test. If isolated restore cannot be demonstrated, production migration remains blocked. Upgrading a plan may be an option, not a presumed requirement.

## Rollback / abort plan (manual; no execution)

1. **Before any apply:** simply close the unmerged PR; no database changes exist.
2. **After a zero-data isolated apply:** disable gameplay flags, drain requests and confirm all new tables contain **zero** user data. Revoke/drop all **eight** new public RPCs (five runtime plus three QA operator endpoints), both internal access/operator helpers, then the new tables in dependency order: `player.run_receipts`, `player.quest_runs`, `player.qa_access`, `canon.quest_releases`. Drop the newly added release guard function and the `player` schema only if empty. Do not use `CASCADE`; do not touch `canon.quest_drafts`, `canon.quest_draft_revisions`, canonical universes or Passport.
3. **If any releases, grants or runs exist:** **do not drop tables**. Disable the feature and apply a reviewed forward fix after exporting/preserving data. Restore only from a verified recovery point with explicit authorization.

**Verified vs proposed:** Existing schema and grants were read-only audited. Prior migration revisions were executed in disposable CI, while the newly proposed QA operator changes await final-head CI. Production backup/restore, application entitlement integration and any deployment remain unverified and unauthorized.
