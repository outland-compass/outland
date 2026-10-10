import { resolveStudioUniverse } from '@/lib/studio/universes';
import { UniverseSelector } from './universe-selector';


import Link from 'next/link';

const spaces = [
  ['Universes', 'Canonical universe identity'],
  ['Canon', 'Franchises, series, characters, factions, lore and rules'],
  ['Worlds', 'Canonical worlds and city relationships'],
  ['Themes', 'Creative identity and style'],
  ['Cities', 'Real-world geographic truth']
];

export const dynamic = 'force-dynamic';
export default async function Studio({ searchParams }: { searchParams: Promise<{ universe?: string }> }) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(params.universe);
  const scoped = (path: string) => selected ? `${path}?universe=${encodeURIComponent(selected.slug)}` : path;
  return (
    <main className="studioDashboard">

      <section className="work">
        <header>
          <div>
            <p className="eyebrow">Canon Editor</p>
            <h1>Studio foundation</h1>
          </div>
          <div>{selected && <UniverseSelector universes={universes} selected={selected.slug} />}</div><b>PRIVATE</b>
        </header>

        <article className="hero">
          <p className="eyebrow">FOLLOW THE SIGNAL.</p>
          <h2>Structure canon first. Then let AI build from approved context.</h2>
          <p className="muted">
            Review canonical data and compile deterministic AI context. Draft writes are available only when explicitly enabled for the staging preview.
          </p>
          <Link className="button" href={scoped('/studio/canon')}>Open Canon Editor</Link>
        </article>

        <section className="grid">
          <article>
            <em>Available now</em>
            <h3>Foundation Editor</h3>
            <p>Review canonical universe, world, theme and canon data. Guarded draft creation is feature-flagged and disabled by default.</p>
          </article>
          <article>
            <em>Available now</em>
            <h3>Canon Inspector</h3>
            <p>Review the selected read model before building Canon Context.</p>
          </article>
          <article>
            <em>Available now</em>
            <h3>Canon Context Builder</h3>
            <p>Compile deterministic AI context from active/approved canon with explicit opt-in for proposed material.</p>
          </article>
          <article>
            <em>Available now</em>
            <h3>City Knowledge Base</h3>
            <p>Build source-backed geographic truth before route, puzzle and story generation.</p>
          </article>
          {spaces.filter(([name]) => name !== 'Canon').map(([name, description]) => (
            <article key={name}>
              <em>Next slices</em>
              <h3>{name}</h3>
              <p>{description}</p>
            </article>
          ))}
        </section>
      </section>
    </main>
  );
}
