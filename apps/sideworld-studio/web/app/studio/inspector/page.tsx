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
          <p className="eyebrow">Studio V0-B</p>
          <h1>Canon Inspector</h1>
        </div>
        <b>READ CONTRACT</b>
      </header>

      <p className="muted">
        Development fixture only. No production database reads or writes are enabled yet.
      </p>

      <section className="inspector-stack">
        <article className="panel">
          <p className="eyebrow">Universe</p>
          <h2>{model.universe.name}</h2>
          <p>{model.universe.description}</p>
          {badge(model.universe.status)}
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
