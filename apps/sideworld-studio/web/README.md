# SIDEWORLD Studio V0-D1

Private SIDEWORLD authoring application.

V0-D1 adds the first **real authoring path**:

- private signed Studio access session;
- server-only Supabase service-role RPC client;
- validated authoring API;
- narrow SECURITY DEFINER save RPCs for Universe, Franchise, Series, Lore Facts and Canon Rules;
- Canon Editor bootstrap UI;
- no direct browser access to private `universe`, `geo` or `canon` schemas;
- no hard delete flow;
- approval/status remains an explicit editor action.

Reads still default to the non-production fixture unless `STUDIO_DATA_SOURCE=supabase` is explicitly configured.

Production deployment and production database changes are not part of V0-D1.
