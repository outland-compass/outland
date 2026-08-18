# OUTLAND

OUTLAND is the platform root. COMPASS Property Radar is its first module.

## Local setup

1. Install and start Docker Desktop.
2. Run `npm install` at the repository root.
3. Run `npm run db:start` and `npm run db:reset`.
4. Generate client types with `npm run db:types`.
5. Configure the Angular local environment with the local Supabase URL and publishable key from `supabase status`.
6. Run `npm run build`.

The browser receives only the Supabase URL and publishable key. Do not add service-role keys, database passwords, or external API secrets to the application.

Assign the first authenticated user an OWNER role after creating it:

```sql
insert into public.user_roles(user_id, role)
values ('<AUTH_USER_UUID>', 'OWNER')
on conflict do nothing;
```

## Verification

Run `npm run db:verify:schema` and `npm run db:verify:workflow-security` after a successful local reset. The workflow/security script runs inside a transaction and rolls back its test records.
