# SIDEWORLD Studio V0-C — Staging Prepare

This folder contains the **read-only staging preparation gate** for the Studio V0-C private read boundary.

It does not contain an Execute mode and cannot apply the migration.

Prepare verifies:

- exact staging target;
- clean pinned checkout;
- pinned migration blob;
- fresh verified staging backup;
- exact 23-version V3.2 baseline;
- V3.2 schemas present;
- Studio RPC absent;
- private schemas still have no API-role USAGE;
- Data API exposure remains `public`, `graphql_public`, `shared`, `land`;
- dry-run lists only `202610070001_sideworld_studio_read_boundary.sql`.

Only after a successful Prepare result and explicit founder authorization should a separate Execute path be created and reviewed.

Post-apply validation SQL is included now so the acceptance criteria are fixed before any write is authorized.
