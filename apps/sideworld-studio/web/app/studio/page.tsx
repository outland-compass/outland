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
        <p className="eyebrow">Studio V0</p>
        <nav>
          {spaces.map(([name]) => <span key={name}>{name}</span>)}
          <Link href="/studio/inspector">Canon Inspector</Link>
        </nav>
        <p className="phase">V0-B · read contract<br/>NO DATABASE WRITES</p>
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
            V0-B now has a typed, server-only read contract and a Canon Inspector using a non-production fixture.
          </p>
          <Link className="button" href="/studio/inspector">Open Canon Inspector</Link>
        </article>

        <section className="grid">
          {spaces.map(([name, description]) => (
            <article key={name}>
              <em>Read model next</em>
              <h3>{name}</h3>
              <p>{description}</p>
            </article>
          ))}
          <article>
            <em>Available now</em>
            <h3>Canon Inspector</h3>
            <p>Review the V3.2 read contract without touching production data.</p>
          </article>
        </section>
      </section>
    </main>
  );
}
