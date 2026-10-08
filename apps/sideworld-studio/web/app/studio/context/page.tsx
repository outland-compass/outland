import Link from 'next/link';

import { buildCanonContextV0 } from '../../../lib/studio/context-builder';
import { getStudioReadModel } from '../../../lib/studio/read-model';

export const dynamic = 'force-dynamic';

export default async function CanonContextPage() {
  const model = await getStudioReadModel();
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

  const pack = buildCanonContextV0(model, { franchiseSlug: franchise.slug });

  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Canon Context Builder V0</p>
          <h1>{pack.universe.name} → {pack.franchise.name}</h1>
        </div>
        <b>DETERMINISTIC</b>
      </header>

      <article className="hero">
        <h2>Approved context only by default.</h2>
        <p className="muted">
          Draft Series and proposed lore are excluded unless an editor explicitly opts them in.
          The generated pack contains no timestamp or random value, so equal inputs produce equal context.
        </p>
      </article>

      <section className="inspector-stack">
        <article className="panel">
          <p className="eyebrow">Included by default</p>
          <div className="row"><strong>Universe</strong><span>{pack.universe.name}</span><span className="status">{pack.universe.status}</span></div>
          <div className="row"><strong>Franchise</strong><span>{pack.franchise.name}</span><span className="status">{pack.franchise.status}</span></div>
          <div className="row"><strong>Worlds</strong><span>{pack.worlds.length}</span><span className="status">active</span></div>
          <div className="row"><strong>Series</strong><span>{pack.series.length}</span><span className="status">active / explicit</span></div>
          <div className="row"><strong>Lore facts</strong><span>{pack.lore.length}</span><span className="status">approved / explicit</span></div>
          <div className="row"><strong>Canon rules</strong><span>{pack.rules.length}</span><span className="status">active</span></div>
          <div className="row"><strong>Cities</strong><span>{pack.cities.length}</span><span className="status">linked / explicit</span></div>
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
