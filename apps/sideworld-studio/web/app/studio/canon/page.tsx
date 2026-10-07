import Link from 'next/link';

import { CanonBootstrapEditor } from './canon-bootstrap-editor';

export default function CanonAuthoringPage() {
  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D2</p>
          <h1>Foundation Editor</h1>
        </div>
        <b>SERVER-WRITE</b>
      </header>

      <p className="muted">
        Bootstrap the first real hierarchy across Universe, World, Theme, Franchise, Series,
        Characters, Factions, Lore, Canon Rules and real City truth. Writes use validated,
        service-role-only server RPCs.
      </p>

      <CanonBootstrapEditor />
      <Link className="button secondaryButton" href="/studio">Back to Studio</Link>
    </main>
  );
}
