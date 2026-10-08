import Link from 'next/link';
import { resolveStudioUniverse } from '@/lib/studio/universes';
import { UniverseSelector } from '../universe-selector';

export const dynamic = 'force-dynamic';

export default async function CanonAuthoringPage({ searchParams }: { searchParams: Promise<{ universe?: string }> }) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(params.universe);
  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D2</p>
          <h1>Foundation Editor</h1>
        </div>
        {selected && <UniverseSelector universes={universes} selected={selected.slug} />}
        <b>READ-ONLY</b>
      </header>
      <p className="muted">Editing is temporarily disabled until server-side universe ownership validation is complete. No data will be changed.</p>
      <Link className="button secondaryButton" href={selected ? '/studio?universe=' + encodeURIComponent(selected.slug) : '/studio'}>Back to Studio</Link>
    </main>
  );
}
