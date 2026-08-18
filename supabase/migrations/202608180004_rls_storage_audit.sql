-- 202608180004_rls_storage_audit.sql
-- OUTLAND COMPASS v0.1 / M2
-- RLS, Storage security and audit trail.

-- Enable RLS on every public application table.
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.worlds enable row level security;
alter table public.score_dimensions enable row level security;
alter table public.world_dimension_weights enable row level security;
alter table public.world_score_criteria enable row level security;
alter table public.world_gate_definitions enable row level security;
alter table public.signals enable row level security;
alter table public.candidates enable row level security;
alter table public.candidate_sources enable row level security;
alter table public.candidate_price_history enable row level security;
alter table public.candidate_media enable row level security;
alter table public.candidate_economics enable row level security;
alter table public.evaluations enable row level security;
alter table public.evaluation_dimension_weights enable row level security;
alter table public.evaluation_items enable row level security;
alter table public.candidate_gates enable row level security;
alter table public.dd_items enable row level security;
alter table public.documents enable row level security;
alter table public.evidence_items enable row level security;
alter table public.notes enable row level security;
alter table public.visits enable row level security;
alter table public.decisions enable row level security;
alter table public.assets enable row level security;
alter table public.activities enable row level security;

-- Profiles
create policy profiles_read_self_or_app on public.profiles
for select to authenticated
using (id = (select auth.uid()) or public.can_read());

create policy profiles_update_self on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- User roles: readable to app users; admin only writes.
create policy user_roles_read on public.user_roles
for select to authenticated using (public.can_read());
create policy user_roles_admin_insert on public.user_roles
for insert to authenticated with check (public.can_admin());
create policy user_roles_admin_update on public.user_roles
for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy user_roles_admin_delete on public.user_roles
for delete to authenticated using (public.can_admin());

-- Config tables: everyone reads; OWNER/ADMIN writes.
create policy worlds_read on public.worlds for select to authenticated using (public.can_read());
create policy worlds_admin_insert on public.worlds for insert to authenticated with check (public.can_admin());
create policy worlds_admin_update on public.worlds for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy worlds_admin_delete on public.worlds for delete to authenticated using (public.can_admin());

create policy score_dimensions_read on public.score_dimensions for select to authenticated using (public.can_read());
create policy score_dimensions_admin_insert on public.score_dimensions for insert to authenticated with check (public.can_admin());
create policy score_dimensions_admin_update on public.score_dimensions for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy score_dimensions_admin_delete on public.score_dimensions for delete to authenticated using (public.can_admin());

create policy world_dimension_weights_read on public.world_dimension_weights for select to authenticated using (public.can_read());
create policy world_dimension_weights_admin_insert on public.world_dimension_weights for insert to authenticated with check (public.can_admin());
create policy world_dimension_weights_admin_update on public.world_dimension_weights for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy world_dimension_weights_admin_delete on public.world_dimension_weights for delete to authenticated using (public.can_admin());

create policy world_score_criteria_read on public.world_score_criteria for select to authenticated using (public.can_read());
create policy world_score_criteria_admin_insert on public.world_score_criteria for insert to authenticated with check (public.can_admin());
create policy world_score_criteria_admin_update on public.world_score_criteria for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy world_score_criteria_admin_delete on public.world_score_criteria for delete to authenticated using (public.can_admin());

create policy world_gate_definitions_read on public.world_gate_definitions for select to authenticated using (public.can_read());
create policy world_gate_definitions_admin_insert on public.world_gate_definitions for insert to authenticated with check (public.can_admin());
create policy world_gate_definitions_admin_update on public.world_gate_definitions for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy world_gate_definitions_admin_delete on public.world_gate_definitions for delete to authenticated using (public.can_admin());

-- Macro-like policy pattern written explicitly for core analyst-write tables.
create policy signals_read on public.signals for select to authenticated using (public.can_read());
create policy signals_write_insert on public.signals for insert to authenticated with check (public.can_analyze());
create policy signals_write_update on public.signals for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy signals_write_delete on public.signals for delete to authenticated using (public.can_analyze());

create policy candidates_read on public.candidates for select to authenticated using (public.can_read());
create policy candidates_write_insert on public.candidates for insert to authenticated with check (public.can_analyze());
create policy candidates_write_update on public.candidates for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy candidates_write_delete on public.candidates for delete to authenticated using (public.can_admin());

create policy candidate_sources_read on public.candidate_sources for select to authenticated using (public.can_read());
create policy candidate_sources_write_insert on public.candidate_sources for insert to authenticated with check (public.can_analyze());
create policy candidate_sources_write_update on public.candidate_sources for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy candidate_sources_write_delete on public.candidate_sources for delete to authenticated using (public.can_analyze());

create policy price_history_read on public.candidate_price_history for select to authenticated using (public.can_read());
create policy price_history_insert on public.candidate_price_history for insert to authenticated with check (public.can_analyze());
create policy price_history_update on public.candidate_price_history for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy price_history_delete on public.candidate_price_history for delete to authenticated using (public.can_admin());

create policy candidate_media_read on public.candidate_media for select to authenticated using (public.can_read());
create policy candidate_media_insert on public.candidate_media for insert to authenticated with check (public.can_analyze());
create policy candidate_media_update on public.candidate_media for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy candidate_media_delete on public.candidate_media for delete to authenticated using (public.can_analyze());

create policy economics_read on public.candidate_economics for select to authenticated using (public.can_read());
create policy economics_insert on public.candidate_economics for insert to authenticated with check (public.can_analyze());
create policy economics_update on public.candidate_economics for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy economics_delete on public.candidate_economics for delete to authenticated using (public.can_admin());

create policy evaluations_read on public.evaluations for select to authenticated using (public.can_read());
create policy evaluations_insert on public.evaluations for insert to authenticated with check (public.can_analyze());
create policy evaluations_update on public.evaluations for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy evaluations_delete on public.evaluations for delete to authenticated using (public.can_admin());

create policy eval_weights_read on public.evaluation_dimension_weights for select to authenticated using (public.can_read());
create policy eval_weights_insert on public.evaluation_dimension_weights for insert to authenticated with check (public.can_analyze());
create policy eval_weights_update on public.evaluation_dimension_weights for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy eval_weights_delete on public.evaluation_dimension_weights for delete to authenticated using (public.can_admin());

create policy eval_items_read on public.evaluation_items for select to authenticated using (public.can_read());
create policy eval_items_insert on public.evaluation_items for insert to authenticated with check (public.can_analyze());
create policy eval_items_update on public.evaluation_items for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy eval_items_delete on public.evaluation_items for delete to authenticated using (public.can_admin());

create policy gates_read on public.candidate_gates for select to authenticated using (public.can_read());
create policy gates_insert on public.candidate_gates for insert to authenticated with check (public.can_analyze());
create policy gates_update on public.candidate_gates for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy gates_delete on public.candidate_gates for delete to authenticated using (public.can_admin());

create policy dd_read on public.dd_items for select to authenticated using (public.can_read());
create policy dd_insert on public.dd_items for insert to authenticated with check (public.can_analyze());
create policy dd_update on public.dd_items for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy dd_delete on public.dd_items for delete to authenticated using (public.can_admin());

-- Evidence contributors include ADVISOR.
create policy documents_read on public.documents for select to authenticated using (public.can_read());
create policy documents_insert on public.documents for insert to authenticated with check (public.can_contribute_evidence());
create policy documents_update on public.documents for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy documents_delete on public.documents for delete to authenticated using (public.can_analyze());

create policy evidence_read on public.evidence_items for select to authenticated using (public.can_read());
create policy evidence_insert on public.evidence_items for insert to authenticated with check (public.can_contribute_evidence());
create policy evidence_update on public.evidence_items for update to authenticated using (public.can_contribute_evidence()) with check (public.can_contribute_evidence());
create policy evidence_delete on public.evidence_items for delete to authenticated using (public.can_analyze());

create policy notes_read on public.notes for select to authenticated using (public.can_read());
create policy notes_insert on public.notes for insert to authenticated with check (public.can_contribute_evidence());
create policy notes_update on public.notes for update to authenticated using (
  public.can_analyze() or created_by = (select auth.uid())
) with check (
  public.can_analyze() or created_by = (select auth.uid())
);
create policy notes_delete on public.notes for delete to authenticated using (
  public.can_analyze() or created_by = (select auth.uid())
);

create policy visits_read on public.visits for select to authenticated using (public.can_read());
create policy visits_insert on public.visits for insert to authenticated with check (public.can_contribute_evidence());
create policy visits_update on public.visits for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy visits_delete on public.visits for delete to authenticated using (public.can_analyze());

create policy decisions_read on public.decisions for select to authenticated using (public.can_read());
create policy decisions_insert on public.decisions for insert to authenticated with check (public.can_analyze());
create policy decisions_update on public.decisions for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy decisions_delete on public.decisions for delete to authenticated using (public.can_admin());

create policy assets_read on public.assets for select to authenticated using (public.can_read());
create policy assets_insert on public.assets for insert to authenticated with check (public.can_admin());
create policy assets_update on public.assets for update to authenticated using (public.can_admin()) with check (public.can_admin());
create policy assets_delete on public.assets for delete to authenticated using (public.can_admin());

create policy activities_read on public.activities for select to authenticated using (public.can_read());
-- No client insert/update/delete policy for activities.

-- Storage bucket.
insert into storage.buckets (id, name, public)
values ('compass-evidence', 'compass-evidence', false)
on conflict (id) do update set public = false;

create policy "compass evidence read"
on storage.objects for select to authenticated
using (bucket_id = 'compass-evidence' and public.can_read());

create policy "compass evidence upload"
on storage.objects for insert to authenticated
with check (bucket_id = 'compass-evidence' and public.can_contribute_evidence());

create policy "compass evidence replace"
on storage.objects for update to authenticated
using (bucket_id = 'compass-evidence' and public.can_analyze())
with check (bucket_id = 'compass-evidence' and public.can_analyze());

create policy "compass evidence delete"
on storage.objects for delete to authenticated
using (bucket_id = 'compass-evidence' and public.can_analyze());

-- Audit trigger. Only key mutable investment tables are audited in v0.1.
create or replace function public.audit_compass_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_id uuid;
  v_entity_id text;
begin
  v_entity_id := coalesce(
    case when tg_op <> 'DELETE' then to_jsonb(new)->>'id' end,
    case when tg_op <> 'INSERT' then to_jsonb(old)->>'id' end
  );

  v_candidate_id := coalesce(
    case when tg_op <> 'DELETE' then nullif(to_jsonb(new)->>'candidate_id','')::uuid end,
    case when tg_op <> 'INSERT' then nullif(to_jsonb(old)->>'candidate_id','')::uuid end,
    case when tg_table_name = 'candidates' and tg_op <> 'DELETE' then new.id else null end,
    case when tg_table_name = 'candidates' and tg_op <> 'INSERT' then old.id else null end
  );

  insert into public.activities(
    candidate_id, entity_type, entity_id, action, actor_id, old_data, new_data
  )
  values (
    v_candidate_id,
    tg_table_name,
    v_entity_id,
    tg_op,
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function public.audit_compass_change() from public;

create trigger audit_candidates after insert or update or delete on public.candidates
for each row execute function public.audit_compass_change();
create trigger audit_candidate_economics after insert or update or delete on public.candidate_economics
for each row execute function public.audit_compass_change();
create trigger audit_evaluations after insert or update or delete on public.evaluations
for each row execute function public.audit_compass_change();
create trigger audit_evaluation_items after insert or update or delete on public.evaluation_items
for each row execute function public.audit_compass_change();
create trigger audit_candidate_gates after insert or update or delete on public.candidate_gates
for each row execute function public.audit_compass_change();
create trigger audit_dd_items after insert or update or delete on public.dd_items
for each row execute function public.audit_compass_change();
create trigger audit_decisions after insert or update or delete on public.decisions
for each row execute function public.audit_compass_change();
