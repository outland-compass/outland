# SIDEWORLD Studio V0-C

Private SIDEWORLD authoring application.

V0-C introduces the **candidate server-side read boundary** for the private V3.2 authoring schemas. It keeps the V0-B non-production fixture as the default and adds an opt-in server-only Supabase RPC path for later staging/production use.

Current boundaries:

- no browser access to `universe`, `geo` or `canon`;
- no direct grants on those private schemas;
- no authoring writes;
- no production seed;
- no CRUD;
- no AI mutation;
- no player/quest runtime;
- `SUPABASE_SERVICE_ROLE_KEY` is server-only and must never use a `NEXT_PUBLIC_*` name;
- `STUDIO_DATA_SOURCE=fixture` remains the default.

The candidate migration creates one read-only `public.sideworld_studio_read_model(text)` RPC. It is `SECURITY DEFINER`, fully qualifies private relations, pins `search_path`, revokes execution from PUBLIC/anon/authenticated, and grants execution only to `service_role`.

The migration, verification test and rollback script are repository candidates only. They are **not authorization to deploy to staging or production**.
