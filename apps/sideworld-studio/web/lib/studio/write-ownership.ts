import 'server-only';
import { callStudioRpc } from './rpc';

// A preflight is not an atomic authorization boundary.
// The write endpoint stays disabled until validation and mutation are transactional.
export async function checkStudioWriteOwnership(universeSlug: string, entity: string, input: Record<string, unknown>) {
  if (!/^[a-z0-9-]+$/.test(universeSlug)) return false;
  const allowed = ['world', 'theme', 'franchise', 'series', 'character', 'faction', 'lore', 'rule'];
  if (!allowed.includes(entity)) return false;
  return callStudioRpc<boolean>('sideworld_studio_check_write_ownership', {
    p_universe_slug: universeSlug, p_entity: entity, p_input: input
  });
}
