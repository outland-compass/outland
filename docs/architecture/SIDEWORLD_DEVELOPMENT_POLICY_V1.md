# SIDEWORLD Development Policy V1 — Production-first

**Status:** Approved project policy (2026-10-08)  
**Applies to:** SIDEWORLD platform development and its integration with existing OUTLAND systems.

## Goal

Maximize development speed and learning while keeping production risk controlled and operational overhead low. Production-first is the default; staging is an optional safety tool, not a mandatory deployment stage.

## Operating rules

1. **Production-first.** Prefer direct production delivery for low-risk changes. Do not require staging for every feature.
2. **Staging on demand.** Use staging for high-risk changes, especially authentication, RLS/permissions, payments, canonical data models, destructive changes, and complex data migrations.
3. **GitHub PR + CI.** Require passing automated checks before merging. Use Vercel preview deployments when useful; they do not imply a staging database is mandatory.
4. **Backup and restore.** Before a direct production database migration, verify backup availability **and** restore readiness. Do not infer restore readiness merely from an enabled backup setting.
5. **Additive migrations.** Preserve existing data, applications, and OUTLAND compatibility. Prefer backward-compatible migrations, with a documented rollback or recovery plan.
6. **Feature flags.** Keep incomplete or experimental features isolated from end users.
7. **Production authorization.** Never execute production database changes without explicit user approval for the proposed change.
8. **Pre-change audit.** Inspect existing production schema, migration history, applications, dependencies, and affected integrations before proposing database changes. Distinguish verified facts from assumptions.
9. **Decision principle.** Maximize development speed without unnecessary infrastructure, process, or uncontrolled risk.

## Risk-based delivery

| Change | Default route |
| --- | --- |
| Documentation, isolated UI, low-risk app logic | PR → CI → production |
| City Knowledge content, quest authoring, AI pipeline iterations | PR → CI → production, with appropriate access controls and feature flags |
| Simple additive database changes | Production-first **only after** dependency audit, backup/restore verification, rollback plan, passing CI, and explicit approval |
| Authentication, RLS, payments, canonical Universe/World models, destructive or complex data migrations | PR → CI → targeted staging rehearsal → explicit production approval |
| Changes affecting existing OUTLAND operations | Review cross-application dependencies; stage when risk warrants |

## Release checklist

- [ ] Scope and affected applications identified
- [ ] Existing production state and dependencies inspected where relevant
- [ ] PR reviewed and required CI checks pass
- [ ] Risk level assessed; staging used only when warranted
- [ ] For production DB migrations: backup and restore readiness verified
- [ ] For production DB migrations: additive compatibility and rollback/recovery documented
- [ ] For production DB migrations: explicit user authorization received
- [ ] Post-deployment smoke checks performed; outcome recorded

## Scope and precedence

This policy changes the **delivery workflow**, not SIDEWORLD's canonical product/data model. SIDEWORLD is the independent platform; OUTLAND is one Universe and has existing operational dependencies. Current architecture authority remains documented in `docs/architecture/README.md` and the canonical architecture documents it references.

Keep the existing staging environment available for selective safety testing. Do not automatically deploy database migrations to production simply because a PR was merged.
