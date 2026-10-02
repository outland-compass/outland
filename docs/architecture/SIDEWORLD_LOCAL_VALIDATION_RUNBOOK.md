# SIDEWORLD Phase 1B: local validation runbook

Status: pending execution. Do not run against production.

1. Check out the existing PR #29 branch and ensure working tree is clean.
2. Inspect current CLI project link and credentials. Verify local Docker/Supabase instance is isolated from remote production.
3. Review the two staged 20261002000* SQL migrations independently before executing them.
4. Start local Supabase and reset only the disposable LOCAL database using the existing npm scripts. Never use remote db push or reset.
5. Run existing schema and workflow-security checks. Run `supabase/tests/verify-sideworld-bases.sql` against local Postgres only, using CLI syntax verified against installed version.
6. On disposable local data, test zero legacy rows, unexpected node types, populated frontiers/spots, source snapshot parity, constraints and client-role access denial.
7. Inspect deployed consumers before planning any legacy removal. Do not drop legacy tables or Passport foreign keys.
8. Record commands, exact results, blockers and rollback plan in PR #29. Keep the PR draft until reviewed.

Do not claim tests passed if they were not executed. Production operations and merge require separate explicit approval.
