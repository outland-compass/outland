# SIDEWORLD Studio

Private SIDEWORLD authoring application.

## V0-A — merged

Established the separate Studio app, navigation shell, visual identity and CI boundary.

## V0-B — this branch

Adds the first **read-only** Studio data path:

- a server-only Supabase client;
- a service-role-only RPC facade in the public API schema;
- Canon Inspector backed by the V3.2 `universe`, `geo` and `canon` foundations;
- no direct Data API exposure of those private schemas;
- no browser service-role credential;
- no authoring writes.

### Runtime configuration

- `SUPABASE_URL` — server-only project URL.
- `SUPABASE_SERVICE_ROLE_KEY` — server-only service role key. Never use a `NEXT_PUBLIC_` prefix.

Until the read RPC migration is approved and applied to an environment, the Inspector renders an explicit unconfigured state.

## Production boundary

Merging code or migrations does not authorize applying the Studio migration to production. Production database execution requires a separate explicit approval and validation step.
