import Link from 'next/link';

const spaces = [
  ['Universes', 'Canonical universe identity'],
  ['Canon', 'Franchises, series, characters, factions, lore and rules'],
  ['Worlds', 'Canonical worlds and city relationships'],
  ['Themes', 'Creative identity and style'],
  ['Cities', 'Real-world geographic truth']
];

export default function Studio() {
  return (
    <main className="shell">
      <aside>
        <p className="brand small">SIDE<span>WORLD</span></p>
        <p className="eyebrow">Studio V0-D1</p>
        <nav>
          <Link href="/studio/canon">Canon Editor</Link>
          <Link href="/studio/inspector">Canon Inspector</Link>
          {spaces.filter(([name]) => name !== 'Canon').map(([name]) => <span key={name}>{name}</span>)}
        </nav>
        <p className="phase">PRIVATE AUTHORING<br/>SERVER-ONLY WRITES</p>
      </aside>

      <section className="work">
        <header>
          <div>
            <p className="eyebrow">Canon Editor</p>
            <h1>Studio foundation</h1>
          </div>
          <b>PRIVATE</b>
        </header>

        <article className="hero">
          <p className="eyebrow">FOLLOW THE SIGNAL.</p>
          <h2>Structure canon first. Then let AI build from approved context.</h2>
          <p className="muted">
            V0-D1 adds protected authoring for Universe, Franchise, Series, Lore and Canon Rules.
          </p>
          <Link className="button" href="/studio/canon">Open Canon Editor</Link>
        </article>

        <section className="grid">
          <article>
            <em>Available now</em>
            <h3>Canon Editor</h3>
            <p>Bootstrap the first canonical hierarchy through validated server-only writes.</p>
          </article>
          <article>
            <em>Available now</em>
            <h3>Canon Inspector</h3>
            <p>Review the selected read model before building Canon Context.</p>
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
