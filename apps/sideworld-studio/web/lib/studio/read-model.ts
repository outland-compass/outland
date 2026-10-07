import 'server-only';

import { studioReadContractFixture } from './fixture';
import type { CanonReadModel } from './types';

type StudioDataSource = 'fixture' | 'supabase';

function dataSource(): StudioDataSource {
  const value = process.env.STUDIO_DATA_SOURCE ?? 'fixture';
  if (value !== 'fixture' && value !== 'supabase') {
    throw new Error('STUDIO_DATA_SOURCE must be fixture or supabase');
  }
  return value;
}

function requiredServerEnv(name: 'SUPABASE_URL' | 'SUPABASE_SERVICE_ROLE_KEY' | 'STUDIO_UNIVERSE_SLUG') {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required when STUDIO_DATA_SOURCE=supabase`);
  return value;
}

async function readFromSupabase(): Promise<CanonReadModel> {
  const baseUrl = requiredServerEnv('SUPABASE_URL').replace(/\/$/, '');
  const serviceRoleKey = requiredServerEnv('SUPABASE_SERVICE_ROLE_KEY');
  const universeSlug = requiredServerEnv('STUDIO_UNIVERSE_SLUG');

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

export async function getStudioReadModel(): Promise<CanonReadModel> {
  if (dataSource() === 'fixture') {
    return structuredClone(studioReadContractFixture);
  }

  return readFromSupabase();
}
