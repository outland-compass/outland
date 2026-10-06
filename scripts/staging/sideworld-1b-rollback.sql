-- Reverse of 202610020001_sideworld_bases_foundation + 202610020002_sideworld_bases_legacy_backfill.
-- Single transaction, no CASCADE: aborts (changing nothing) if any other object depends on infrastructure.*.
-- Legacy universe.* / passport.* are untouched by the forward migrations, so nothing needs restoring there.
-- Valid only BEFORE the Legacy Universe V0 cleanup (20261004140102): afterwards Bases/audit are the only copy
-- of the node data, so the script refuses to run.
\set ON_ERROR_STOP 1
begin;
do $$ begin
  if to_regclass('universe.nodes') is null then
    raise exception 'Legacy Universe V0 cleanup is applied: Bases/audit hold the only copy of node data - SIDEWORLD 1B rollback refused';
  end if;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'infrastructure' and c.relkind in ('r','v','m','p')
               and c.relname not in ('bases','base_legacy_migration_audit')) then
    raise exception 'infrastructure schema contains objects not created by SIDEWORLD 1B - manual review';
  end if;
end $$;
-- IF EXISTS: also valid for the partial state "foundation applied, backfill failed" (the CLI commits
-- each migration separately, and a failed backfill rolls back on its own).
drop table if exists infrastructure.base_legacy_migration_audit;
drop table if exists infrastructure.bases;
drop schema if exists infrastructure;
delete from supabase_migrations.schema_migrations where version in ('202610020001','202610020002');
commit;
