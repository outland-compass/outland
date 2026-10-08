# SIDEWORLD Studio V0-D2

Private SIDEWORLD authoring application.

V0-D2 extends the real authoring path across the V3.2 foundation:

- Universe;
- World and World ↔ City relationship;
- Theme;
- Franchise and Series;
- Character and Faction;
- Lore Facts and Canon Rules;
- Country and City truth.

All writes pass through validated server endpoints and narrow `SECURITY DEFINER` RPCs executable only by `service_role`. The browser receives neither private-schema access nor the service-role credential. `universe`, `geo` and `canon` remain outside Data API exposure and have no direct API-role USAGE.

The development fixture no longer pretends that BEYOND THE ATLAS is a Universe. BEYOND THE ATLAS remains the approved Franchise; its owning Universe must be chosen explicitly before real canon is seeded.

There is still no hard-delete flow. Production remains untouched.

## Studio Auth V1 (preview rollout)

Studio login uses Supabase email/password. Existing `public.can_admin()` checks `shared.user_roles` for `OWNER` or `ADMIN`; a valid user without that role is denied. Login, logout and password recovery are available; MFA is intentionally deferred. The old shared access-key endpoint returns HTTP 410.

Required per environment: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and (for existing authoring/read RPCs) `SUPABASE_SERVICE_ROLE_KEY`, `STUDIO_UNIVERSE_SLUG`. Configure Preview to use staging Supabase only. Add `https://<preview-host>/reset-password` to Supabase Auth redirect allowlist; keep signups restricted and create/grant admins explicitly. Never put the service-role key in browser variables.

Auth routes use secure HttpOnly cookies and server-side `/auth/v1/user` plus `/rest/v1/rpc/can_admin` checks. Add an edge/WAF rate limit for login and reset endpoints before external exposure. Test invalid password, non-admin, admin, expired/refresh session, logout, reset, unauthorized write and CSRF; no production authorization or deployment is implied by this PR.

NOTE: This auth branch was based on main; merge/rebase the independent Supabase-only runtime PR #59 first, then resolve any integration conflicts and rerun all checks.
