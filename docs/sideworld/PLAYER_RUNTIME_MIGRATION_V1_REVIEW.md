# SIDEWORLD Player Runtime V1 — migration review and rollback

**Status (updated 2026-10-14):** APPLIED to both staging and production **exactly once**, under separate founder authorization. Production ledger version `20261014104136` verified, RLS and RPC roles checked, 0 data. **Gameplay and private QA activation remain OFF.** Full independent evidence: [Production deployment record](PLAYER_RUNTIME_PRODUCTION_DEPLOYMENT_2026_10_14.md). This document retains earlier pre-application checklists as historical audit records. Tracking: [OUTLAND #69](https://github.com/outland-compass/outland/issues/69), [Player #12](https://github.com/outland-compass/sideworld_app/issues/12).

## Read-only evidence, 2026-10-13

- Audited actual production (`huzcukdovavejejwohey`) and staging (`clgpxvyflycudzhdzjlv`) schema inventories, grants/RLS/functions and OUTLAND migrations `202610060004_sideworld_canon_foundation.sql`, `20261012151318_sideworld_quest_drafts_v1.sql` and `20260913141314_universe_v0_core_and_passport_journey.sql`.
- Existing `canon.quest_drafts` / `canon.quest_draft_revisions` are Studio-owned and RLS-enabled; their full latest-draft RPC is service-role-only and includes hidden answers and future content. They are not published content.
- No dedicated immutable playable release or Player progress store exists in inspected schemas. Existing `passport.journeys` / `passport.events` represent OUTLAND World-profile travel, not puzzle session state.
- Canonical `universe.universes`, `canon.franchises`, `canon.series`, `geo.cities` exist; this migration creates no duplicate registry. `canon.quest_draft_revisions` already has primary key (`draft_id,revision`).
- Player main now contains the generic engine, server-owned RPC adapter, separate QA identity, gated HTTP API and mobile renderer (merged Player PRs #15/#18/#19). Live gameplay remains OFF. Existing Studio editorial login requires OWNER/ADMIN; ordinary testers must never inherit that role.
- Three older same-name migrations use different timestamps across production/staging. Key seven table-column schemas and eleven Studio/admin function definitions were identical in read-only comparisons; staging-only rehearsal occurred without rewriting any historical ledger.
- Fresh encrypted production backup and isolated **application-table restore fingerprints** verified in Studio Actions [#38550055892](https://github.com/outland-compass/sideworld_studio/actions/runs/38550055892), 2026-10-14. Founder attested off-site encrypted backup custody and separate key storage; external checksum/decryption were not independently inspected. Full managed Auth/Storage recovery remains unverified. The exact SQL subsequently received approval and was applied.

## Proposed additive structure

| Relation | Why it exists |
| --- | --- |
| `canon.quest_releases` | One versioned, frozen copy of an existing draft revision. Opaque UUID release ID; source document and engine hash immutable. `private_qa`, `published`, `retired` visibility; publication requires editorial, field and media approvals. Contains private answer keys; never browser-readable. |
| `player.qa_access` | Expiring, revocable actor/release tester entitlement distinct from Studio OWNER/ADMIN. |
| `player.quest_runs` | Trusted actor-owned version-bound progress, sequence and private engine event history, not an OUTLAND Passport journey. |
| `player.run_receipts` | Bounded, transactional idempotency receipt for the 16 most recent commands per run; prevents double-unlock and duplicate progression. |

Eight proposed `public.sideworld_player_*` RPC functions are **service-role-only**: five runtime functions (release read, start, run read, receipt read, atomic compare-and-save) plus three private QA operations (release create, grant, revoke). Table RLS is ON with no client policies and no direct role grants. Internal helpers enforce QA eligibility and Studio operator roles.

The migration creates **zero releases, zero QA grants and zero runs**. It now proposes narrowly authorized create/grant/revoke RPCs **for private QA only**; it does **not** include a public publish/approve, reset API, Studio admin HTTP workflow or automatic tester invitation. An authenticated Studio server route must derive the operator UUID from verified Auth, check OWNER/ADMIN and call the privileged RPC with explicit operator approval. The SQL also checks `shared.user_roles`. The Player-only manifest helper (merged Player PR #20) computes the actual engine hash; it performs no writes. Do not treat this migration alone as an invitation to play.

### Trust boundary — important

The database RPC accepts actorId and private next-progress state only from a **trusted Player server** using a privileged credential. The server must verify Supabase Auth JWT, derive actorId (never trust it from browser JSON), select an explicitly authorized immutable release, execute the TypeScript gameplay engine, and submit only a validated transition. The RPC provides atomicity/idempotency but **does not validate game answers or independently authenticate a JWT**. A leaked service-role credential has broad blast radius. Evaluate a narrowly scoped service gateway before public launch.

The `engine_content_hash` is a deterministic engine binding computed from the validated TypeScript input `{questId: sourceDraftId, revision: sourceRevision, document}`; it is **not a cryptographic signature** or a PostgreSQL-recomputed value. The release-trigger enforces JSONB equality with the originating Studio revision on insert; no mutation of content/source/hash after creation.

For `run_apply`, a row-level `FOR UPDATE` lock serializes commands. Existing receipt with same UUID and fingerprint returns the saved result; a different fingerprint conflicts. New commands must match the latest sequence and append exactly one event with unchanged version/hash. The update and receipt insert/prune are one transaction. Missing/expired QA grant denies even on resume. Retention: 16 receipts/run, 256 KiB maximum progress per snapshot; older retry IDs return safe stale conflicts, not double-advance.

### Limits explicitly deferred

- Storing a progress event history in every receipt is acceptable for private MVP **only** with bounds. Revisit data growth, replay cost, retention and event compaction before multi-city scale.
- `quest_runs.status` is initially `in_progress`; completion/abandon and reset must have future trusted, engine-validated RPC logic.
- User experience, public catalog, browser session, source/media licensing, verified physical stops and payment entitlements are not implemented.
- The SQL including QA operator RPCs passed disposable PostgreSQL 17 replay, synthetic SQL and two-connection CAS at source head `0eaea1f`; it was also applied to the authorized staging database and passed role/functional rollback tests. The file was renamed with identical blob content to match staging's generated migration version. **Final PR head `ba15306` passed all five Database CI and Web CI checks.** Live browser Auth, actual Studio V2 source and field QA are unverified.

## Mandatory checks before considering database application

- [x] Compared 38 historic migration names (three timestamp differences), seven key table-column schemas and eleven Studio/admin functions. [ ] Complete grant, trigger and broader app dependency review for production.
- [x] Previous migration version executed in disposable PostgreSQL 17 CI (four replay paths). **Re-run/verify all checks at this updated PR head.** Do NOT use production SQL for a parse test.
- [x] Ran exactly the repository's schema/grant assertion SQL, direct `anon`/`authenticated` denials, and safe `service_role` RPC read on actual staging.
- [x] Tested synthetic Studio draft/releases, admin-only create, QA grant/revoke/regrant, idempotency, actor isolation and invalid transitions on disposable DB and actual staging, with ROLLBACK and zero remaining fixtures.
- [x] Prior head: two independent PostgreSQL sessions raced one run/sequence and passed one-write CAS test. Receipt replay and stale/conflicting commands passed transactional fixture. **Final-head CI and fault-injection edge cases remain review items.**
- [ ] Validate the exact seven-scene Studio V2 document privately only after authorized snapshot is created. Never send raw `answerKey` or progress history to a browser.
- [x] Fresh 2026-10-14 encrypted production export and isolated application-table restore passed; [ ] separately preserve archive and key, validate broader managed-service disaster recovery scope.
- [ ] GitHub PR and automated checks must pass. Obtain explicit founder approval of the exact SQL, backup/restore evidence and deployment window before any production migration. High-risk RLS/auth changes warrant staging rehearsal; staging otherwise remains optional.


## Private QA operator workflow — schema deployed, activation pending

1. An authenticated **Studio OWNER/ADMIN** explicitly chooses a stored `draft_id` and exact revision, reads the complete authoring document from a trusted server-only path, and checks editorial diagnostics. Never trust an actor UUID or authoring document submitted by the browser.
2. The Player's server-only `preparePrivateQaRelease` calculates `engineContentHash` with the actual generic engine and emits an **answer-free** manifest. It is not an approval, signature, publication or database update.
3. A privileged Studio server calls `sideworld_player_qa_release_create_v1(operator,draft,revision,hash)`. The proposed database function separately confirms `shared.user_roles` OWNER/ADMIN, frozen exact Studio revision, `draft` status, no error diagnostics and private QA visibility. Idempotent repetition returns the same release; any checksum mismatch conflicts.
4. A privileged operator calls `sideworld_player_qa_grant_v1(operator,release,tester,expires_at)`, only for existing Supabase Auth users, with 5-minute minimum and 14-day maximum expiry. Testers do not receive Studio admin privileges. `sideworld_player_qa_revoke_v1` revokes access immediately at the release entitlement check; a conscious future re-grant can reactivate it.
5. The Player loader **independently** validates the release content and recomputes the hash before game start, resume or action; neither the manifest nor Studio admin credentials reach the browser.

The RPCs alone are insufficient for gameplay activation. Studio PRs #38 and #39 merged the feature-gated admin API and confirmation UI into Studio `main` but the verified Vercel Studio production deployment remained on an older commit. Persistent tamper-evident operator audit and verified distributed rate limiting are **not yet operational**. Both Stage and Production remain with zero authorized Player content/user runs; do not activate gameplay or auto-mark sources, field safety or media as approved.

## Backup and restore evidence — mandatory operational gate

The Supabase connector does not expose managed backups, but the independent GitHub Actions [run #38550055892](https://github.com/outland-compass/sideworld_studio/actions/runs/38550055892) confirmed a fresh encrypted production export and isolated application-table restore. Encrypted artifact `production-backup-38550055892` (ID 11886865484, 480770 bytes) expires **2026-10-21T10:34:35Z**. Managed recovery completeness and billing tier remain unverified; founder attested off-GitHub encrypted-copy custody with key stored separately, but external checksum and decryption not independently checked.

Current Supabase [Database Backups](https://supabase.com/docs/guides/platform/backups) guidance: daily managed backups are available on paid plans; Free projects should maintain external logical dumps through `supabase db dump`. See [Backup/Restore CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) for role, schema and data export/restore instructions.

**Operator evidence required before applying PR #70:** identify the actual plan and available backup timestamp or create a fresh encrypted off-site logical dump. Preserve `auth`, migration history, Vault/encryption requirements, relevant non-database Storage objects, and any custom roles/triggers. Restore into an isolated disposable environment, test expected critical tables, functions and representative records, record timestamp/checksum and who verified the restore. An untested file or a green migration replay is **not** restore readiness. Never put credentials or customer data into GitHub/CI artifacts or public logs. Staging migration drift must be reconciled separately.

Do not restore **over** the production database as a test. If isolated restore cannot be demonstrated, production migration remains blocked. Upgrading a plan may be an option, not a presumed requirement.

## Staging-only rehearsal — VERIFIED (2026-10-14)

The exact SQL blob from source head `0eaea1fbed5a81a9275f29a00477f39ac143e17a` was applied with Supabase `apply_migration` to **`outland-staging` (`clgpxvyflycudzhdzjlv`) ONLY**, as approved. The tool assigned ledger version **`20261014104136`**, name `sideworld_player_runtime_v1`. The repository file was subsequently renamed to `supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql` with the **same blob SHA `8fcca2a8a0eec82f4dd899412e14848d279b9295`**. No SQL content changed.

**Preflight:** PostgreSQL 17 staging healthy, 38 preceding migration records, no existing `player` schema/tables/functions, no duplicate canonical entities, existing composite Studio draft revision key/RLS/role dependencies verified.

**Postflight:** 39 staging migration records; four new tables with RLS ON and **zero** client policies/direct grants. All eight public RPCs executable only by `service_role` (not `anon` or `authenticated`). Source/actor helpers not directly executable by API roles. No seeded release, tester entitlement, run or receipt.

**Executed on actual staging:** `verify-sideworld-player-runtime.sql` PASS; `verify-sideworld-player-client-denials.sql` as `anon` and `authenticated` PASS; complete `verify-sideworld-player-runtime-transactions.sql` synthetic release/QA/atomic progress/grant/revoke lifecycle PASS inside BEGIN/ROLLBACK; separate `SET LOCAL ROLE service_role` nonexistent-run query returned null. Post-test query confirmed zero synthetic users/drafts/releases and **zero** runtime rows. Two concurrent PostgreSQL sessions were separately tested only in disposable Database CI, **not** on live staging.

Supabase Security Advisor reports `rls_enabled_no_policy` INFO for four new tables, **intentional private deny-by-default**, not an accidental public exposure. Other advisor WARN items concern pre-existing Auth/functions and are not silently marked as fixed. At staging-test time production did not yet have those tables. **Later production postflight confirms all four exist with RLS ON and zero rows.**

**Historical staging boundary:** The staging-only approval did not authorize production. A later explicit founder authorization was given and **this exact migration was applied once to production**. This is not authorization to rerun it or enable gameplay. See the independent production postflight record linked above.


## Rollback / abort plan (manual; no execution)

1. **Before any apply:** simply close the unmerged PR; no database changes exist.
2. **After a zero-data isolated apply:** disable gameplay flags, drain requests and confirm all new tables contain **zero** user data. Revoke/drop all **eight** new public RPCs (five runtime plus three QA operator endpoints), both internal access/operator helpers, then the new tables in dependency order: `player.run_receipts`, `player.quest_runs`, `player.qa_access`, `canon.quest_releases`. Drop the newly added release guard function and the `player` schema only if empty. Do not use `CASCADE`; do not touch `canon.quest_drafts`, `canon.quest_draft_revisions`, canonical universes or Passport.
3. **If any releases, grants or runs exist:** **do not drop tables**. Disable the feature and apply a reviewed forward fix after exporting/preserving data. Restore only from a verified recovery point with explicit authorization.

**Verified vs proposed (final state):** The exact approved SQL was applied once to production after staging replay, source reconciliation and founder authorization. Production postflight and matching staging/production ledger MD5 are recorded separately. Source CI fully passed. Operator UI code exists in Studio `main` but is not in the verified deployed Studio build. Full managed Auth/Storage recovery, distributed rate limits, durable audit, actual Player/Studio Auth handshake, live gameplay and field QA remain outstanding.
