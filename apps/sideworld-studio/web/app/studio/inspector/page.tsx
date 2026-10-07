import Link from 'next/link';

import { getStudioReadModel } from '@/lib/studio/read-model';

function badge(value: string) {
  return <span className="status">{value.replaceAll('_', ' ')}</span>;
}

export default async function CanonInspectorPage() {
  const model = await getStudioReadModel();

  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D3</p>
          <h1>Canon Inspector</h1>
        </div>
        <b>CONTEXT-READY</b>
      </header>

      <p className="muted">
        Shows the deterministic Studio read model that will feed Canon Context Builder V0.
        Fixture mode is non-production; Supabase mode reads through the private server boundary.
      </p>

      <section className="inspector-stack">
        <article className="panel">
          <p className="eyebrow">Universe</p>
          <h2>{model.universe.name}</h2>
          <p>{model.universe.description}</p>
          {badge(model.universe.status)}
        </article>

        <article className="panel">
          <p className="eyebrow">Worlds</p>
          {model.worlds.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{item.summary ?? '—'}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Themes</p>
          {model.themes.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{Object.keys(item.styleProfile).length ? JSON.stringify(item.styleProfile) : 'No style profile yet'}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Franchises</p>
          {model.franchises.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>canon v{item.canonVersion}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Series</p>
          {model.series.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{item.premise}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Characters</p>
          {model.characters.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.displayName ?? item.name}</strong>
              <span>{item.role ?? '—'} · {item.bio ?? 'No bio'}</span>
              {badge(item.canonStatus)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Character relationships</p>
          {model.relationships.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.relationshipType}</strong>
              <span>{item.characterAId} → {item.characterBId} · {item.description ?? '—'}</span>
              {badge(item.canonStatus)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Factions</p>
          {model.factions.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{item.description ?? item.factionType ?? '—'}</span>
              {badge(item.canonStatus)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Lore</p>
          {model.lore.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.factKey}</strong>
              <span>{item.statement}</span>
              {badge(item.canonStatus)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Canon rules</p>
          {model.rules.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.ruleType}</strong>
              <span>{item.ruleText}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Cities</p>
          {model.cities.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{item.timezone} · {item.defaultLocale}</span>
              {badge(item.verificationStatus)}
            </div>
          ))}
        </article>
      </section>

      <Link className="button" href="/studio">Back to Studio</Link>
    </main>
  );
}
