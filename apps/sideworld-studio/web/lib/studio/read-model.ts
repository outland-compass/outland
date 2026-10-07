import 'server-only';

import { createClient } from '@supabase/supabase-js';

export type StudioSnapshot = {
  universes: Record<string, unknown>[];
  worlds: Record<string, unknown>[];
  themes: Record<string, unknown>[];
  franchises: Record<string, unknown>[];
  series: Record<string, unknown>[];
  characters: Record<string, unknown>[];
  relationships: Record<string, unknown>[];
  factions: Record<string, unknown>[];
  lore_facts: Record<string, unknown>[];
  canon_rules: Record<string, unknown>[];
  cities: Record<string, unknown>[];
  world_cities: Record<string, unknown>[];
};

const emptySnapshot: StudioSnapshot = {
  universes: [],
  worlds: [],
  themes: [],
  franchises: [],
  series: [],
  characters: [],
  relationships: [],
  factions: [],
  lore_facts: [],
  canon_rules: [],
  cities: [],
  world_cities: []
};

export type StudioReadResult =
  | { state: 'ready'; data: StudioSnapshot }
  | { state: 'unconfigured'; data: StudioSnapshot }
  | { state: 'error'; data: StudioSnapshot; message: string };

export async function getStudioSnapshot(universeId?: string): Promise<StudioReadResult> {
  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    return { state: 'unconfigured', data: emptySnapshot };
  }

  const supabase = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data, error } = await supabase.rpc('sideworld_studio_snapshot', {
    p_universe_id: universeId ?? null
  });

  if (error) {
    return { state: 'error', data: emptySnapshot, message: error.message };
  }

  return { state: 'ready', data: (data ?? emptySnapshot) as StudioSnapshot };
}
