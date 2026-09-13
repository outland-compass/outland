insert into universe.nodes (
  world_id,
  asset_id,
  code,
  name,
  node_type,
  status,
  metadata
)
select
  w.id,
  null,
  'N.01',
  'GREENHILL N·01',
  'stay',
  'planned',
  jsonb_build_object(
    'display_code', 'N·01',
    'implementation_order', 1,
    'canon_status', 'working'
  )
from shared.worlds w
where w.code = 'GREENHILL'
  and not exists (
    select 1
    from universe.nodes n
    where n.world_id = w.id
      and n.code = 'N.01'
  );
