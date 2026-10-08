import Link from 'next/link';
import { LogoutButton } from './logout-button';

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
        <p className="eyebrow">Studio V0-E / Context Builder</p>
        <nav>
          <Link href="/studio/canon">Canon Editor</Link>
          <Link href="/studio/inspector">Canon Inspector</Link>
          <Link href="/studio/context">Canon Context</Link>
          <Link href="/studio/city">City Knowledge</Link>
          {spaces.filter(([name]) => name !== 'Canon').map(([name]) => <span key={name}>{name}</span>)}
        </nav>
        <LogoutButton />
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
            The canonical authoring foundation is now ready to compile deterministic AI context from approved records.
          </p>
          <Link className="button" href="/studio/canon">Open Canon Editor</Link>
        </article>

        <section className="grid">
          <article>
            <em>Available now</em>
            <h3>Foundation Editor</h3>
            <p>Bootstrap Universe → World/Theme → Canon → City through validated server-only writes.</p>
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
