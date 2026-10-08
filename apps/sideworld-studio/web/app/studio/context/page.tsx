import { resolveStudioUniverse } from '@/lib/studio/universes';
import { UniverseSelector } from '../universe-selector';
import Link from 'next/link';

import { buildCanonContextV0 } from '../../../lib/studio/context-builder';
import { getStudioReadModel } from '../../../lib/studio/read-model';

export const dynamic = 'force-dynamic';

type SearchParams = Record<string, string | string[] | undefined>;

function values(params: SearchParams, key: string) {
  const value = params[key];
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

export default async function CanonContextPage({
  searchParams
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const { universes, selected } = await resolveStudioUniverse(typeof params.universe === 'string' ? params.universe : undefined);
  const model = await getStudioReadModel(selected?.slug);
  const franchise = model.franchises.find((item) => item.status === 'active');

  if (!franchise) {
    return (
      <main className="work">
        <p className="eyebrow">Canon Context Builder V0</p>
        <h1>No active franchise</h1>
        <p className="muted">Create or activate a franchise before compiling context.</p>
        <Link className="button" href="/studio">Back to Studio</Link>
      </main>
    );
  }

  const selectedSeries = values(params, 'series');
  const selectedWorlds = values(params, 'world');
  const selectedCities = values(params, 'city');
  const selectedLore = values(params, 'lore');

  const pack = buildCanonContextV0(model, {
    franchiseSlug: franchise.slug,
    seriesSlugs: selectedSeries,
    worldSlugs: selectedWorlds,
    citySlugs: selectedCities,
    proposedLoreKeys: selectedLore
  });

  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Canon Context Builder V0</p>
          <h1>{pack.universe.name} → {pack.franchise.name}</h1>
        </div>
        {selected && <UniverseSelector universes={universes} selected={selected.slug} />}<b>DETERMINISTIC</b>
      </header>

      <article className="hero">
        <h2>Approved context only by default.</h2>
        <p className="muted">
          Draft Series, proposed lore, Worlds and Cities enter only when an editor explicitly selects them.
          The generated pack contains no timestamp or random value, so equal inputs produce equal context.
        </p>
      </article>

      <form className="contextSelector" method="get">{selected && <input type="hidden" name="universe" value={selected.slug} />}
        <article className="panel">
          <p className="eyebrow">Explicit context selection</p>

          <fieldset>
            <legend>Series</legend>
            {model.series.length === 0 ? <p className="muted">No Series available.</p> : model.series.map((item) => (
              <label key={item.id}>
                <input
                  defaultChecked={selectedSeries.includes(item.slug)}
                  name="series"
                  type="checkbox"
                  value={item.slug}
                />
                <span>{item.name}</span>
                <small>{item.status}</small>
              </label>
            ))}
          </fieldset>

          <fieldset>
            <legend>Worlds</legend>
            {model.worlds.length === 0 ? <p className="muted">No approved spatial Worlds exist yet.</p> : model.worlds.map((item) => (
              <label key={item.id}>
                <input
                  defaultChecked={selectedWorlds.includes(item.slug)}
                  name="world"
                  type="checkbox"
                  value={item.slug}
                />
                <span>{item.name}</span>
                <small>{item.status}</small>
              </label>
            ))}
          </fieldset>

          <fieldset>
            <legend>Cities</legend>
            {model.cities.length === 0 ? <p className="muted">No Cities available.</p> : model.cities.map((item) => (
              <label key={item.id}>
                <input
                  defaultChecked={selectedCities.includes(item.slug)}
                  name="city"
                  type="checkbox"
                  value={item.slug}
                />
                <span>{item.name}</span>
                <small>{item.verificationStatus}</small>
              </label>
            ))}
          </fieldset>

          <fieldset>
            <legend>Proposed lore</legend>
            {model.lore.filter((item) => item.canonStatus === 'proposed').length === 0
              ? <p className="muted">No proposed lore available.</p>
              : model.lore.filter((item) => item.canonStatus === 'proposed').map((item) => (
                <label key={item.id}>
                  <input
                    defaultChecked={selectedLore.includes(item.factKey)}
                    name="lore"
                    type="checkbox"
                    value={item.factKey}
                  />
                  <span>{item.factKey}</span>
                  <small>{item.canonStatus}</small>
                </label>
              ))}
          </fieldset>

          <button className="button" type="submit">Compile context</button>
        </article>
      </form>

      <section className="inspector-stack">
        <article className="panel">
          <p className="eyebrow">Compiled context</p>
          <div className="row"><strong>Universe</strong><span>{pack.universe.name}</span><span className="status">{pack.universe.status}</span></div>
          <div className="row"><strong>Franchise</strong><span>{pack.franchise.name}</span><span className="status">{pack.franchise.status}</span></div>
          <div className="row"><strong>Worlds</strong><span>{pack.worlds.length}</span><span className="status">explicit</span></div>
          <div className="row"><strong>Series</strong><span>{pack.series.length}</span><span className="status">active / explicit</span></div>
          <div className="row"><strong>Lore facts</strong><span>{pack.lore.length}</span><span className="status">approved / explicit</span></div>
          <div className="row"><strong>Canon rules</strong><span>{pack.rules.length}</span><span className="status">active</span></div>
          <div className="row"><strong>Cities</strong><span>{pack.cities.length}</span><span className="status">explicit</span></div>
        </article>

        <article className="panel">
          <p className="eyebrow">Context payload preview</p>
          <pre className="contextPayload">{JSON.stringify(pack, null, 2)}</pre>
        </article>
      </section>

      <Link className="button secondaryButton" href="/studio/inspector">Open Canon Inspector</Link>
    </main>
  );
}
