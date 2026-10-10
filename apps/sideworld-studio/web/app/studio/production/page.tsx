import Link from 'next/link';
import { resolveStudioUniverse } from '@/lib/studio/universes';
import { getStudioReadModel } from '@/lib/studio/read-model';
import { getCityKnowledge } from '@/lib/studio/city-knowledge';
import { buildCanonContextV0 } from '@/lib/studio/context-builder';
import { buildProductionInputManifestV1 } from '@/lib/studio/production-manifest';
import { puzzleMechanicsV1 } from '@/lib/studio/puzzle-mechanics';
import { UniverseSelector } from '../universe-selector';

export const dynamic = 'force-dynamic';

export default async function ProductionPage({ searchParams }: { searchParams: Promise<{ universe?: string; city?: string }> }) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(params.universe);
  const model = await getStudioReadModel(selected?.slug);
  const franchise = model.franchises.find(item => item.status === 'active');
  const city = model.cities.find(item => item.slug === params.city) ?? model.cities[0];
  const knowledge = city ? await getCityKnowledge(city.id) : null;
  const context = franchise ? buildCanonContextV0(model, { franchiseSlug: franchise.slug, citySlugs: city ? [city.slug] : [] }) : null;
  const manifest = context && knowledge ? buildProductionInputManifestV1(context, knowledge) : null;
  const checks = [
    { label: 'Universe selected', pass: !!selected },
    { label: 'Active franchise', pass: !!franchise },
    { label: 'City selected', pass: !!city },
    { label: 'Verified or partially verified city', pass: !!city && ['verified', 'partially_verified'].includes(city.verificationStatus) },
    { label: 'At least five mapped locations', pass: (knowledge?.locations.length ?? 0) >= 5 },
    { label: 'Source-backed city facts available', pass: (knowledge?.facts.length ?? 0) > 0 && (knowledge?.sources.length ?? 0) > 0 },
    { label: 'Canon context compiled', pass: !!context }
  ];
  const ready = checks.every(check => check.pass);
  const scoped = (path: string) => selected ? path + '?universe=' + encodeURIComponent(selected.slug) : path;

  return <main className="work">
    <header><div><p className="eyebrow">AI Studio · Production readiness V0</p><h1>Quest Production</h1></div>
      {selected && <UniverseSelector universes={universes} selected={selected.slug} />}
      <b>{ready ? 'INPUT READY' : 'INPUT GAPS'}</b>
    </header>
    <article className="hero"><h2>Validate the inputs before AI generation.</h2>
      <p className="muted">This is a deterministic preflight for the future AI City Factory. It does not call an AI model, generate a quest, publish content or write to the database.</p>
    </article>
    <form method="get" className="contextSelector">
      {selected && <input type="hidden" name="universe" value={selected.slug} />}
      <label htmlFor="production-city">City</label>
      <select id="production-city" name="city" defaultValue={city?.slug ?? ''}>
        {model.cities.map(item => <option key={item.id} value={item.slug}>{item.name} ({item.verificationStatus})</option>)}
      </select>
      <button className="button" type="submit">Check readiness</button>
    </form>
    <section className="inspector-stack">
      <article className="panel"><h2>Input readiness</h2>
        {checks.map(check => <div className="row" key={check.label}><strong>{check.label}</strong><span className="status">{check.pass ? 'PASS' : 'NEEDS WORK'}</span></div>)}
      </article>
      <article className="panel"><h2>Available source material</h2>
        <div className="row"><strong>Locations</strong><span>{knowledge?.locations.length ?? 0}</span></div>
        <div className="row"><strong>Facts</strong><span>{knowledge?.facts.length ?? 0}</span></div>
        <div className="row"><strong>Sources</strong><span>{knowledge?.sources.length ?? 0}</span></div>
        <div className="row"><strong>Canon rules</strong><span>{context?.rules.length ?? 0}</span></div>
        <p className="muted">Passing these checks does not certify pedestrian safety, factual accuracy or publication quality. Field QA remains mandatory.</p>
      </article>
    </section>
    <section className="inspector-stack"><article className="panel"><h2>Production Input Manifest V1</h2>
      <p className="muted">Verified public locations and source-backed facts only. A manifest is not an AI-generated quest or a publishing approval.</p>
      <p className="status">{manifest?.readyForGeneration ? 'INPUTS VALIDATED' : 'BLOCKED'}</p>
      {manifest?.diagnostics.map(issue => <div className="row" key={issue.code}><strong>{issue.code}</strong><span>{issue.message}</span></div>)}
      {manifest && <details><summary>Inspect manifest JSON</summary><pre className="contextPayload">{JSON.stringify(manifest, null, 2)}</pre></details>}
    </article></section>
    <section className="inspector-stack"><article className="panel"><h2>Puzzle Mechanics Library V1</h2>
      <p className="muted">Reusable authoring contracts; no puzzle generation or publication is enabled.</p>
      {puzzleMechanicsV1.map(mechanic => <div className="row" key={mechanic.id}><strong>{mechanic.label}</strong><span>{mechanic.playerInteraction.replaceAll('_', ' ')}</span><span className="status">v{mechanic.version}</span></div>)}
    </article></section>
    <Link className="button secondaryButton" href={scoped('/studio/context')}>Review Canon Context</Link>
  </main>;
}
