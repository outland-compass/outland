# Phase 1B — Bases migration specification

Status: design only, not applied.

- Create private `infrastructure.bases` with UUID PK, required `world_id` FK to `shared.worlds`, optional `asset_id` FK to `shared.assets`, name, status, optional positive guest capacity, metadata and timestamps. Defer `location_id` FK until `geography.locations` exists.
- Keep a private migration audit with source table, source UUID, new Base UUID and complete source row JSON. It is provenance, not a second accommodation table.
- Backfill only legacy `node_type='stay'` rows. Match rows using source UUID, not potentially duplicated names. Fail if unknown node types or unexpected nonempty frontier/spot tables appear.
- Validate counts, world identity, metadata and timestamp parity before allowing legacy cleanup.
- Enable RLS with no public grants or policies by default. Add only audited access policies when app needs them.
- Preserve legacy tables and Passport FKs until all consumers are migrated and isolated regression tests pass.
- Rollback before cleanup: drop only new private audit and Base tables after checking that no new application data has been written. After cutover use backup and mapping-based recovery, not blind DROP.

Open verification: full deployed-client inventory, isolated migration replay, backup restore, security tests and explicit production approval.