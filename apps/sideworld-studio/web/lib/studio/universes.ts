import 'server-only';

export type StudioUniverse = { id: string; slug: string; name: string; status: string };

export async function listStudioUniverses(): Promise<StudioUniverse[]> {
  const url = process.env.SUPABASE_URL?.trim();
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !key) throw new Error('Studio Supabase configuration missing');
  const response = await fetch(
    `${url.replace(/\/$/, '')}/rest/v1/universes?select=id,slug,name,status&order=name.asc`,
    { headers: { apikey: key, Authorization: `Bearer ${key}`, 'Accept-Profile': 'universe' }, cache: 'no-store' }
  );
  if (!response.ok) throw new Error(`Universe catalog unavailable (HTTP ${response.status})`);
  const rows: unknown = await response.json();
  if (!Array.isArray(rows)) throw new Error('Invalid universe catalog');
  return rows.filter((row): row is StudioUniverse => !!row && typeof row === 'object' &&
    typeof row.id === 'string' && typeof row.slug === 'string' && typeof row.name === 'string' && typeof row.status === 'string');
}

export async function resolveStudioUniverse(requested?: string) {
  const universes = await listStudioUniverses();
  if (!universes.length) return { universes, selected: null };
  const selected = universes.find(item => item.slug === requested) ?? universes.find(item => item.slug === 'outland') ?? universes[0];
  return { universes, selected };
}
