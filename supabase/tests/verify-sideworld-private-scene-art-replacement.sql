-- Post-migration, read-only assertions (staging first).
DO $$
begin
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='canon' and c.relname='quest_visual_binding_replacements'
      and c.relrowsecurity
  ) then raise exception 'Missing RLS-protected replacement audit'; end if;

  if has_table_privilege('anon','canon.quest_visual_binding_replacements','SELECT') or
     has_table_privilege('authenticated','canon.quest_visual_binding_replacements','SELECT') or
     has_table_privilege('service_role','canon.quest_visual_binding_replacements','UPDATE')
  then raise exception 'Replacement history grants are too broad'; end if;

  if has_function_privilege('anon',
      'public.sideworld_quest_visual_replace_private_v1(uuid,uuid,text,text,uuid,uuid)','EXECUTE') or
     has_function_privilege('authenticated',
      'public.sideworld_quest_visual_replace_private_v1(uuid,uuid,text,text,uuid,uuid)','EXECUTE') or
     not has_function_privilege('service_role',
      'public.sideworld_quest_visual_replace_private_v1(uuid,uuid,text,text,uuid,uuid)','EXECUTE')
  then raise exception 'Replacement RPC must be service-role-only'; end if;

  if not exists (
     select 1 from pg_trigger t
     where t.tgrelid='canon.quest_visual_binding_replacements'::regclass
       and t.tgname='quest_visual_binding_replacements_immutable_v1'
       and t.tgenabled='O'
  ) then raise exception 'Replacement audit must be append-only'; end if;

  if not exists (
     select 1 from pg_constraint c where c.conrelid='canon.quest_visual_bindings'::regclass
       and c.conname='quest_visual_bindings_pkey'
  ) then raise exception 'Immutable binding identity unexpectedly changed'; end if;

  if not exists (
     select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='sideworld_quest_visual_replace_private_v1'
       and pg_get_functiondef(p.oid) like '%v_binding.asset_id<>p_expected_asset%'
       and pg_get_functiondef(p.oid) like '%v_release.visibility not in (%'
       and pg_get_functiondef(p.oid) like '%v_next.brief_id<>v_previous.brief_id%'
  ) then raise exception 'Missing compare-and-swap / private / brief checks'; end if;
end $$;
select 'PASS: service-only private scene swap, append-only audit, existing binding constraints intact' as result;
