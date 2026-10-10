'use client';

import { useState } from 'react';

type Character = { id: string; slug: string; name: string; canon_status: string };
type Asset = { id: string; character_id: string; visual_version: number; asset_role: string; approval_status: string; source_sha256: string; storage_path: string; rights_note: string; approved_at: string | null; created_at: string };
type Gallery = { characters: Character[]; assets: Asset[] };

export default function CharacterGallery() {
  const [gallery, setGallery] = useState<Gallery | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [rightsNotes, setRightsNotes] = useState<Record<string, string>>({});
  const [approvalMessage, setApprovalMessage] = useState('');
  const [approvingId, setApprovingId] = useState<string | null>(null);
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
  async function approve(asset: Asset) {
    const rightsNote = rightsNotes[asset.id]?.trim() || '';
    if (rightsNote.length < 20 || approvingId) return;
    if (!window.confirm('Approve this exact draft portrait and SHA-256? This changes canonical media status.')) return;
    setApprovingId(asset.id);
    setApprovalMessage('Submitting approval...');
    try {
      const response = await fetch('/api/studio/character-approval', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'approve', assetId: asset.id,
          characterId: asset.character_id, expectedSha256: asset.source_sha256, rightsNote })
      });
      if (!response.ok) throw new Error(`Approval rejected (HTTP ${response.status})`);
      setApprovalMessage('Portrait approved. Refreshing gallery.');
      await refresh();
    } catch (error) {
      setApprovalMessage(error instanceof Error ? error.message : 'Approval unavailable');
    } finally {
      setApprovingId(null);
    }
  }
  return <section className="panel">
    <h2>Canonical character gallery</h2>
    <p className="muted">Live, admin-only metadata from THE UNCHARTED / Beyond the Atlas. Drafts are not approvals. Private portrait images are not exposed.</p>
    <button type="button" disabled={loading} onClick={() => { void refresh(); }}>{loading ? 'Loading…' : 'Refresh canonical gallery'}</button>
    {error && <p role="alert">{error}</p>}
    {approvalMessage && <p role="status">{approvalMessage}</p>}
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
              {asset.approval_status === 'draft' && <>
                <label>Usage rights and approval justification (minimum 20 characters)
                  <textarea value={rightsNotes[asset.id] || ''}
                    onChange={event => setRightsNotes(previous => ({ ...previous, [asset.id]: event.target.value }))} />
                </label>
                <button type="button" disabled={approvingId !== null || (rightsNotes[asset.id]?.trim().length || 0) < 20}
                  onClick={() => { void approve(asset); }}>
                  {approvingId === asset.id ? 'Approving…' : 'Approve exact draft'}
                </button>
                <p className="muted">Server-side approval remains disabled unless separately enabled by an administrator.</p>
              </>}
            </div>)}
        </article>;
      })}
    </>}
  </section>;
}
