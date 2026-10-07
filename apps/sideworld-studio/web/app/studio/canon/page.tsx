import Link from 'next/link';

import { CanonBootstrapEditor } from './canon-bootstrap-editor';

export default function CanonAuthoringPage() {
  return (
    <main className="work">
      <header>
        <div>
          <p className="eyebrow">Studio V0-D1</p>
          <h1>Canon Editor</h1>
        </div>
        <b>SERVER-WRITE</b>
      </header>

      <p className="muted">
        Bootstrap authoring for Universe → Franchise → Series → Lore → Canon Rules.
        Writes go through validated server-only RPCs. Approval remains explicit.
      </p>

      <CanonBootstrapEditor />
      <Link className="button secondaryButton" href="/studio">Back to Studio</Link>
    </main>
  );
}
