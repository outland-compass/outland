import Link from 'next/link';
import { GuardedEditor } from './guarded-editor';
import { resolveStudioUniverse } from '@/lib/studio/universes';
import { UniverseSelector } from '../universe-selector';

export const dynamic = 'force-dynamic';

export default async function CanonAuthoringPage({ searchParams }: { searchParams: Promise<{ universe?: string }> }) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(params.universe);
  const enabled = process.env.SIDEWORLD_STUDIO_GUARDED_WRITES === 'enabled';
  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D2</p>
          <h1>Foundation Editor</h1>
        </div>
        {selected && <UniverseSelector universes={universes} selected={selected.slug} />}
        <b>{enabled ? 'GUARDED DRAFTS' : 'READ-ONLY'}</b>
      </header>
      {enabled && selected ? <GuardedEditor universeId={selected.id} universeSlug={selected.slug} /> : <p className="muted">Editing is disabled until guarded staging writes are enabled. No data will be changed.</p>}
      <Link className="button secondaryButton" href={selected ? '/studio?universe=' + encodeURIComponent(selected.slug) : '/studio'}>Back to Studio</Link>
    </main>
  );
}
