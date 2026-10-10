import 'server-only';

// Ownership must be checked inside the same PostgreSQL transaction as mutation.
// A separate service-role RPC preflight would create a time-of-check/time-of-use gap.
// This intentionally fails closed until a transactional guarded-write RPC is deployed.
export function assertStudioWriteReady(): never {
  throw new Error('Studio writes disabled until transactional universe ownership checks are deployed');
}
