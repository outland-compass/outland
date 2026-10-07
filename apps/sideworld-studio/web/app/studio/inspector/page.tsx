import Link from 'next/link';

import { getStudioSnapshot } from '@/lib/studio/read-model';

export const dynamic = 'force-dynamic';

const groups = [
  ['universes', 'Universes'],
  ['worlds', 'Worlds'],
  ['themes', 'Themes'],
  ['franchises', 'Franchises'],
  ['series', 'Series'],
  ['characters', 'Characters'],
  ['relationships', 'Relationships'],
  ['factions', 'Factions'],
  ['lore_facts', 'Lore facts'],
  ['canon_rules', 'Canon rules'],
  ['cities', 'Cities'],
  ['world_cities', 'World ↔ City links']
] as const;

function rowLabel(row: Record<string, unknown>) {
  return String(row.display_name ?? row.name ?? row.fact_key ?? row.rule_type ?? row.slug ?? row.id ?? 'Untitled');
}

function rowStatus(row: Record<string, unknown>) {
  return String(row.canon_status ?? row.status ?? row.verification_status ?? row.visibility ?? '');
}

export default async function CanonInspectorPage() {
  const result = await getStudioSnapshot();

  return (
    <main className="inspectorPage">
      <header className="inspectorHeader">
        <div>
          <p className="eyebrow">Studio V0-B</p>
          <h1>Canon Inspector</h1>
        </div>
        <Link href="/studio">Back to Studio</Link>
      </header>

      {result.state === 'unconfigured' && (
        <section className="notice">
          <strong>Read model is not connected in this environment.</strong>
          <p>Configure server-only SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY after the read-only RPC migration is approved and applied.</p>
        </section>
      )}

      {result.state === 'error' && (
        <section className="notice error">
          <strong>Read model error.</strong>
          <p>{result.message}</p>
        </section>
      )}

      <section className="inspectorGrid">
        {groups.map(([key, title]) => {
          const rows = result.data[key];
          return (
            <article className="inspectorGroup" key={key}>
              <header><h2>{title}</h2><span>{rows.length}</span></header>
              {rows.length === 0 ? (
                <p className="empty">No records</p>
              ) : (
                <ul>
                  {rows.slice(0, 12).map((row, index) => (
                    <li key={String(row.id ?? row.fact_key ?? index)}>
                      <span>{rowLabel(row)}</span>
                      {rowStatus(row) && <em>{rowStatus(row)}</em>}
                    </li>
                  ))}
                </ul>
              )}
            </article>
          );
        })}
      </section>
    </main>
  );
}
