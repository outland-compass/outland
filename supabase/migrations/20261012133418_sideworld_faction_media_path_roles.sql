-- Explicit illustration roles for the three Order of Light paths. No character or symbol changes.
alter table canon.faction_visual_assets drop constraint faction_visual_assets_asset_role_check;
alter table canon.faction_visual_assets add constraint faction_visual_assets_asset_role_check
 check (asset_role in ('canonical_illustration','symbol','reference_sheet','seers','teachers','warriors'));
