import { resolveStudioUniverse } from '@/lib/studio/universes';
import { UniverseSelector } from '../universe-selector';
import Link from 'next/link';

import { getCityKnowledge } from '../../../lib/studio/city-knowledge';
import { getStudioReadModel } from '../../../lib/studio/read-model';
import { CityKnowledgeEditor } from './city-knowledge-editor';

export const dynamic = 'force-dynamic';

type SearchParams = Record<string, string | string[] | undefined>;

export default async function CityKnowledgePage({
  searchParams
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(typeof params.universe === 'string' ? params.universe : undefined);
  const model = await getStudioReadModel(selected?.slug);
  const requested = typeof params.city === 'string' ? params.city : undefined;
  const city = model.cities.find((item) => item.slug === requested) ?? model.cities[0];

  if (!city) {
    return (
      <main className="work">
        <p className="eyebrow">City Knowledge Base V0</p>
        <h1>No City available</h1>
        <Link className="button" href="/studio">Back to Studio</Link>
      </main>
    );
  }

  const knowledge = await getCityKnowledge(city.id);

  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">City Knowledge Base V0</p>
          <h1>{city.name}</h1>
        </div>
        {selected && <UniverseSelector universes={universes} selected={selected.slug} />}<b>{city.verificationStatus}</b>
      </header>

      <article className="hero">
        <h2>Geographic truth before generated story.</h2>
        <p className="muted">
          Locations, factual statements and evidence sources stay separate from fictional canon.
          Verification status and confidence remain explicit throughout the AI pipeline.
        </p>
      </article>

      <section className="grid">
        <article><em>Locations</em><h3>{knowledge.locations.length}</h3><p>Physical anchors with coordinates and access metadata.</p></article>
        <article><em>Facts</em><h3>{knowledge.facts.length}</h3><p>Sourceable claims for route, puzzle and story generation.</p></article>
        <article><em>Sources</em><h3>{knowledge.sources.length}</h3><p>Evidence linked to facts with support semantics.</p></article>
      </section>

      <CityKnowledgeEditor cityId={city.id} />

      <section className="inspector-stack">
        <article className="panel">
          <p className="eyebrow">Knowledge payload preview</p>
          <pre className="contextPayload">{JSON.stringify(knowledge, null, 2)}</pre>
        </article>
      </section>

      <Link className="button secondaryButton" href="/studio/context">Open Canon Context</Link>
    </main>
  );
}
