-- READ ONLY: Sideworld-specific recovery canaries for a protected local export.
-- This never changes database state, creates group objects or exports private
-- quest content, authentication records, invitation secrets or role clues.
-- Run through trusted psql with /out mounted to an encrypted local directory.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;

-- Actual row counts of the canonical universes, geo, authoring and Player
-- data families that the old OUTLAND-only inventory did not cover.
\copy (select 'auth.users' as object, count(*)::bigint as n from auth.users union all select 'universe.universes',count(*) from universe.universes union all select 'universe.worlds',count(*) from universe.worlds union all select 'geo.locations',count(*) from geo.locations union all select 'canon.quest_drafts',count(*) from canon.quest_drafts union all select 'canon.quest_draft_revisions',count(*) from canon.quest_draft_revisions union all select 'canon.quest_releases',count(*) from canon.quest_releases union all select 'player.quest_runs',count(*) from player.quest_runs union all select 'player.run_receipts',count(*) from player.run_receipts union all select 'player.private_access',count(*) from player.private_access union all select 'player.qa_access',count(*) from player.qa_access order by object) to '/out/sideworld-counts.csv' csv header

-- Hash canaries, NOT raw documents, answer keys, actor IDs or auth data.
-- The content digest only detects an unauthorized or incomplete restore; it
-- is NOT proof of Player/Studio normalization parity or licensed content.
\copy (select id::text release_id,source_draft_id::text draft_id,source_revision,visibility,engine_content_hash,md5(document::text) as document_md5 from canon.quest_releases order by id) to '/out/sideworld-release-canaries.csv' csv header

-- Metadata-only access-control baseline for existing private tables; Group
-- tables (when absent) remain recorded separately without assuming DDL.
\copy (select n.nspname||'.'||c.relname as object,c.relrowsecurity as rls_enabled,c.relforcerowsecurity as rls_forced,has_table_privilege('anon',c.oid,'SELECT') as anon_select,has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select,has_table_privilege('service_role',c.oid,'SELECT') as service_select,(select count(*) from pg_policy p where p.polrelid=c.oid) as policy_count from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('r','p') and n.nspname in ('canon','geo','player','universe') order by 1) to '/out/sideworld-rls.csv' csv header

-- Current Group migration and object existence is evidence, not permission
-- to apply migration or enable multiplayer.
\copy (select 'player.group_sessions' as object,(to_regclass('player.group_sessions') is not null) as exists union all select 'player.group_members',to_regclass('player.group_members') is not null union all select 'player.group_receipts',to_regclass('player.group_receipts') is not null union all select 'migration.20261024040523',exists(select 1 from supabase_migrations.schema_migrations where version='20261024040523') union all select p.proname,p.oid is not null from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'sideworld_group_%_v1' order by 1) to '/out/sideworld-group-objects.csv' csv header

\copy (select extname,extversion from pg_extension order by extname) to '/out/sideworld-extensions.csv' csv header

rollback;
