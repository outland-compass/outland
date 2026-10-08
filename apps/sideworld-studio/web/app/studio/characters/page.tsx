import Link from 'next/link';
import { beyondAtlasCharacterImportPreviewV1 as preview } from '@/lib/studio/beyond-atlas-character-preview';

export default function CharacterSourcePreviewPage() {
  return <main className="work">
    <header><div><p className="eyebrow">AI Studio · Character source import V0</p><h1>Beyond the Atlas — Character Bible</h1></div><b>READ ONLY</b></header>
    <article className="hero"><h2>Reuse the existing approved character direction.</h2>
      <p className="muted">Source: {preview.source} · Version {preview.sourceVersion}. This is a manually mapped preview, not a live Word parser, media import or database write.</p>
    </article>
    <section className="inspector-stack">
      <article className="panel"><h2>Character mapping preview</h2>
        {preview.characters.map(character => <div className="row" key={character.slug}>
          <strong>{character.name}</strong><span>{character.role}</span><span>{character.visual}</span><span className="status">{character.visualStatus.replaceAll('_', ' ')}</span>
        </div>)}
      </article>
      <article className="panel"><h2>Import blockers</h2>
        {preview.warnings.map(warning => <p key={warning} className="muted">{warning}</p>)}
        <p className="muted">Existing franchise/character IDs, images, permissions and approvals must be reconciled before import. Published quests will pin immutable visual versions.</p>
      </article>
    </section>
    <Link className="button secondaryButton" href="/studio">Back to Studio</Link>
  </main>;
}
