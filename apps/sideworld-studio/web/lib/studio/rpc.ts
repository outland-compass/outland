import 'server-only';

function requiredServerEnv(name: 'SUPABASE_URL' | 'SUPABASE_SERVICE_ROLE_KEY') {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required for Studio server RPCs`);
  return value;
}

export async function callStudioRpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const baseUrl = requiredServerEnv('SUPABASE_URL').replace(/\/$/, '');
  const serviceRoleKey = requiredServerEnv('SUPABASE_SERVICE_ROLE_KEY');

  const response = await fetch(`${baseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`Studio RPC ${name} failed with HTTP ${response.status}${detail ? `: ${detail.slice(0, 300)}` : ''}`);
  }

  return await response.json() as T;
}
