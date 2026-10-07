-- SIDEWORLD Studio V0-C rollback
-- Run only as an explicit operator action if the V0-C read boundary must be removed.
begin;

revoke all on function public.sideworld_studio_read_model(text)
  from public, anon, authenticated, service_role;

drop function if exists public.sideworld_studio_read_model(text);

commit;
