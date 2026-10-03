# Phase 1B — Bases migration

Status: SQL and read-only verification staged in draft PR #29. NOT tested, merged or applied.

Files:
- `supabase/migrations/202610020001_sideworld_bases_foundation.sql`
- `supabase/migrations/202610020002_sideworld_bases_legacy_backfill.sql`
- `supabase/tests/verify-sideworld-bases.sql`

Creates private `infrastructure.bases` and migration audit; retains canonical `shared.worlds`, `shared.assets`, all legacy tables and Passport FKs. Guest capacity remains unknown for GREENHILL. Geographic FK deferred until geography.locations exists. Source UUID mapping and full original node snapshot are retained.

**Required before merge:** Claude Code must independently review SQL correctness, migration order, RLS privileges, timestamp parity, empty and unexpected-data cases, audit completeness and rollback; replay from clean local database; run existing schema and security tests plus the new verification script. Existing `verify-schema.sql` intentionally still asserts legacy tables because cleanup is a later phase. Test and report any incompatibility rather than changing historic applied migrations.

**Required before production:** inspect all deployed consumers and current live migration parity; restore-test a backup and obtain separate explicit approval. Do not drop legacy tables, alter Passport FKs, merge or deploy as part of this PR without review.

Rollback before any new application writes: after confirming no dependent data, remove only newly introduced private infrastructure tables and schema if empty. After new writes, use audited mapping and backup-based recovery; never blind-drop.
