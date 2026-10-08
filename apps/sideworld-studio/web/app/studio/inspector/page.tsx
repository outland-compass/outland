import Link from 'next/link';

import { getStudioReadModel } from '@/lib/studio/read-model';

export const dynamic = 'force-dynamic';

function badge(value: string) {
  return <span className="status">{value.replaceAll('_', ' ')}</span>;
}

export default async function CanonInspectorPage() {
  const model = await getStudioReadModel();

  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D2</p>
          <h1>Canon Inspector</h1>
        </div>
        <b>READ CONTRACT</b>
      </header>

      <p className="muted">
        Shows canonical Studio data from Supabase through the private server boundary.
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
              <span>{item.summary ?? item.slug}</span>
              {badge(item.status)}
            </div>
          ))}
        </article>

        <article className="panel">
          <p className="eyebrow">Themes</p>
          {model.themes.map((item) => (
            <div className="row" key={item.id}>
              <strong>{item.name}</strong>
              <span>{item.description ?? item.slug}</span>
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
          <p className="eyebrow">World ↔ City</p>
          {model.worldCities.map((item) => (
            <div className="row" key={`${item.worldId}:${item.cityId}`}>
              <strong>{item.relationshipType}</strong>
              <span>{item.worldId} → {item.cityId}</span>
              {badge('linked')}
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
