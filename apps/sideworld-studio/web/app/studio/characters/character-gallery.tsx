'use client';

import { useState } from 'react';

type Character = { id: string; slug: string; name: string; canon_status: string };
type Asset = { id: string; character_id: string; visual_version: number; asset_role: string; approval_status: string; source_sha256: string; storage_path: string; rights_note: string; approved_at: string | null; created_at: string };
type Gallery = { characters: Character[]; assets: Asset[] };

export default function CharacterGallery() {
  const [gallery, setGallery] = useState<Gallery | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  async function refresh() {
    setLoading(true);
    setError('');
    try {
      const response = await fetch('/api/studio/character-gallery?universe=the-uncharted', { cache: 'no-store' });
      if (!response.ok) throw new Error(`Gallery unavailable (HTTP ${response.status})`);
      const data = await response.json() as Gallery;
      setGallery(data);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Gallery unavailable');
    } finally {
      setLoading(false);
    }
  }
  return <section className="panel">
    <h2>Canonical character gallery</h2>
    <p className="muted">Live, admin-only metadata from THE UNCHARTED / Beyond the Atlas. Drafts are not approvals. Private portrait images are not exposed.</p>
    <button type="button" disabled={loading} onClick={() => { void refresh(); }}>{loading ? 'Loading…' : 'Refresh canonical gallery'}</button>
    {error && <p role="alert">{error}</p>}
    {gallery && <>
      <p role="status">{gallery.characters.length} canonical characters · {gallery.assets.length} registered visual assets</p>
      {gallery.characters.map(character => {
        const assets = gallery.assets.filter(asset => asset.character_id === character.id);
        return <article className="row" key={character.id}>
          <strong>{character.name}</strong>
          <span className="muted">{character.slug} · character {character.canon_status}</span>
          {assets.length === 0 ? <span className="muted">No stored portrait yet</span> : assets.map(asset =>
            <div key={asset.id}>
              <strong>V{asset.visual_version} · {asset.asset_role} · {asset.approval_status}</strong>
              <p className="muted">SHA-256: {asset.source_sha256}</p>
              <p className="muted">Storage path: {asset.storage_path}</p>
              <p className="muted">Rights: {asset.rights_note}</p>
              {asset.approved_at && <p className="muted">Approved: {asset.approved_at}</p>}
            </div>)}
        </article>;
      })}
    </>}
  </section>;
}
