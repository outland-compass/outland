import 'server-only';

import type { CanonReadModel } from './types';
import { resolveStudioUniverse } from './universes';

function requiredServerEnv(name: 'SUPABASE_URL' | 'SUPABASE_SERVICE_ROLE_KEY') {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

async function readFromSupabase(requestedSlug?: string): Promise<CanonReadModel> {
  const baseUrl = requiredServerEnv('SUPABASE_URL').replace(/\/$/, '');
  const serviceRoleKey = requiredServerEnv('SUPABASE_SERVICE_ROLE_KEY');
  const { selected } = await resolveStudioUniverse(requestedSlug);
  if (!selected) throw new Error('No universes available in Studio');
  const universeSlug = selected.slug;

  const response = await fetch(`${baseUrl}/rest/v1/rpc/sideworld_studio_read_model`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({ p_universe_slug: universeSlug })
  });

  if (!response.ok) {
    throw new Error(`Studio read RPC failed with HTTP ${response.status}`);
  }

  const model = (await response.json()) as CanonReadModel;

  if (!model.universe) {
    throw new Error(`Studio universe not found: ${universeSlug}`);
  }

  return model;
}

export async function getStudioReadModel(universeSlug?: string): Promise<CanonReadModel> {
  return readFromSupabase(universeSlug);
}
