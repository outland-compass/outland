'use client';

import { useEffect, useState } from 'react';
import { beyondAtlasCharacterImportPreviewV1 as bible } from '@/lib/studio/beyond-atlas-character-preview';

type ImageRecord = {
  file: string;
  sha256: string;
  sourcePart: string;
  nearbyText: string[];
  possibleCharacters: string[];
  reviewStatus: string;
  approved: boolean;
};
type Report = { source: string; sourceSha256: string; extractionVersion: number; images: ImageRecord[] };
type Assignment = { characterSlug: string; decision: 'candidate' | 'reject' };

export default function CharacterMediaReview() {
  const [report, setReport] = useState<Report | null>(null);
  const [assignments, setAssignments] = useState<Record<string, Assignment>>({});
  const [error, setError] = useState('');
  const [roster, setRoster] = useState<Array<{ id: string; slug: string; name: string }>>([]);
  const [uploadStatus, setUploadStatus] = useState('');
  const [originalFiles, setOriginalFiles] = useState<Record<string, File>>({});
  const [previews, setPreviews] = useState<Record<string, { url: string; verified: boolean }>>({});
  useEffect(() => () => { Object.values(previews).forEach(preview => { if (preview.url) URL.revokeObjectURL(preview.url); }); }, [previews]);
  async function load(file: File) {
    try {
      const raw: unknown = JSON.parse(await file.text());
      if (!raw || typeof raw !== 'object' || !('images' in raw) || !Array.isArray(raw.images) ||
          !('source' in raw) || typeof raw.source !== 'string' ||
          !('sourceSha256' in raw) || typeof raw.sourceSha256 !== 'string' ||
          !('extractionVersion' in raw) || !Number.isInteger(raw.extractionVersion) ||
          !raw.images.every((image: unknown) => image && typeof image === 'object' &&
            'file' in image && typeof image.file === 'string' && /^image[0-9]+\\.(png|jpe?g|webp)$/i.test(image.file) &&
            'sha256' in image && typeof image.sha256 === 'string' && /^[a-f0-9]{64}$/.test(image.sha256) &&
            (!('nearbyText' in image) || (Array.isArray(image.nearbyText) && image.nearbyText.every((value: unknown) => typeof value === 'string'))))) {
        throw new Error('Invalid extraction report');
      }
      const source = raw as Report;
      setReport({ ...source, images: source.images.map(image => ({
        ...image,
        nearbyText: Array.isArray(image.nearbyText) ? image.nearbyText : [],
        possibleCharacters: Array.isArray(image.possibleCharacters) ? image.possibleCharacters : [],
        sourcePart: typeof image.sourcePart === 'string' ? image.sourcePart : '',
        reviewStatus: typeof image.reviewStatus === 'string' ? image.reviewStatus : 'unreviewed',
        approved: image.approved === true
      })) });
      setPreviews({});
      setAssignments({});
      setError('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Cannot parse report');
      setReport(null);
    }
  }
  async function loadOriginalImages(files: FileList | null) {
    if (!files || !report) return;
    const next: Record<string, { url: string; verified: boolean }> = {};
    for (const file of Array.from(files)) {
      const source = report.images.find(image => image.file === file.name);
      if (!source || !file.type.startsWith('image/')) continue;
      const bytes = await file.arrayBuffer();
      const digest = await crypto.subtle.digest('SHA-256', bytes);
      const hash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
      const verified = hash === source.sha256.toLowerCase();
      next[file.name] = { url: verified ? URL.createObjectURL(file) : '', verified };
    }
    setPreviews(next);
    setOriginalFiles(Object.fromEntries(Array.from(files).map(file => [file.name, file])));
  }
  async function loadRoster() {
    setUploadStatus('');
    try {
      const response = await fetch('/api/studio/character-roster?universe=the-uncharted', { cache: 'no-store' });
      if (!response.ok) throw new Error('Character roster is unavailable');
      const payload = await response.json() as { characters: Array<{ id: string; slug: string; name: string }> };
      setRoster(payload.characters);
    } catch (error) {
      setUploadStatus(error instanceof Error ? error.message : 'Roster unavailable');
    }
  }
  async function uploadAmonDraft() {
    const canonical = bible.editorialDecisions.amonDimano;
    const original = originalFiles[canonical.canonicalSourceFile];
    const character = roster.find(entry => entry.slug === 'amon-dimano');
    if (!original || !previews[canonical.canonicalSourceFile]?.verified || !character) {
      setUploadStatus('Verified Amon original and canonical character record are required');
      return;
    }
    const body = new FormData();
    body.set('file', original);
    body.set('characterId', character.id);
    body.set('visualVersion', String(canonical.visualVersion));
    body.set('sha256', canonical.canonicalSha256);
    body.set('sourceDocument', bible.source);
    setUploadStatus('Uploading original as draft...');
    try {
      const response = await fetch('/api/studio/character-media?universe=the-uncharted', { method: 'POST', body });
      if (!response.ok) throw new Error(`Upload rejected (HTTP ${response.status})`);
      setUploadStatus('Original stored as draft. Editorial approval remains separate.');
    } catch (error) {
      setUploadStatus(error instanceof Error ? error.message : 'Upload failed');
    }
  }
  function downloadMapping() {
    if (!report) return;
    const payload = {
      source: report.source, sourceSha256: report.sourceSha256,
      mappingVersion: 1, editorialDecisions: bible.editorialDecisions, assignments: report.images.map(image => ({
        file: image.file, sha256: image.sha256,
        characterSlug: image.file === bible.editorialDecisions.amonDimano.canonicalSourceFile && image.sha256 === bible.editorialDecisions.amonDimano.canonicalSha256 ? 'amon-dimano' : assignments[image.sha256]?.characterSlug || null,
        decision: image.file === bible.editorialDecisions.amonDimano.canonicalSourceFile && image.sha256 === bible.editorialDecisions.amonDimano.canonicalSha256 ? 'canonical_source_selected' : image.file === bible.editorialDecisions.amonDimano.archivedAlternativeFile ? 'archived_alternative' : assignments[image.sha256]?.decision || 'unreviewed',
        approved: false
      }))
    };
    const url = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' }));
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'beyond-atlas-media-mapping-draft.json';
    anchor.click();
    URL.revokeObjectURL(url);
  }
  return <section className="panel">
    <h2>Original illustration review</h2>
    <p className="muted">Load the extraction-report.json produced from the original Word document. Review and SHA-256 verification happen in your browser. Explicit admin upload stores a draft in private staging storage; editorial approval remains separate.</p>
    <label>Extraction report (JSON) <input type="file" accept=".json,application/json" onChange={event => { const file = event.target.files?.[0]; if (file) void load(file); }} /></label>
    {error && <p role="alert">{error}</p>}
    {report && <>
      <button type="button" onClick={() => { void loadRoster(); }}>Load canonical character IDs</button>
      <p className="muted">{roster.length} characters loaded from THE UNCHARTED / Beyond the Atlas. Upload remains disabled until the server feature flag is enabled.</p>
      <button type="button" disabled={!roster.some(item => item.slug === 'amon-dimano') || !previews[bible.editorialDecisions.amonDimano.canonicalSourceFile]?.verified} onClick={() => { void uploadAmonDraft(); }}>Upload approved Amon original as draft</button>
      {uploadStatus && <p role="status">{uploadStatus}</p>}

      <label>Original portrait files <input type="file" multiple accept="image/png,image/jpeg,image/webp" onChange={event => { void loadOriginalImages(event.target.files); }} /></label>
      <p>{report.images.length} embedded images · source {report.source}</p>
      {report.images.map((image, index) => <article key={image.sha256 + ':' + index} className="row">
        <strong>{image.file}</strong>
        {previews[image.file]?.verified
          ? <img src={previews[image.file].url} alt={'Original illustration ' + image.file} style={{ width: 180, maxHeight: 240, objectFit: 'contain' }} />
          : <span className="muted">Original image not selected or SHA-256 mismatch</span>}
        {image.file === bible.editorialDecisions.amonDimano.canonicalSourceFile &&
          image.sha256 === bible.editorialDecisions.amonDimano.canonicalSha256 &&
          <strong>Amon Dimano — approved canonical portrait V1</strong>}
        <span className="muted">{image.nearbyText.join(' · ').slice(0, 300)}</span>
        {image.file !== bible.editorialDecisions.amonDimano.canonicalSourceFile && image.file !== bible.editorialDecisions.amonDimano.archivedAlternativeFile && <>
        <label>Candidate character
          <select value={assignments[image.sha256]?.characterSlug ?? ''} onChange={event => setAssignments(old => ({
            ...old, [image.sha256]: { characterSlug: event.target.value, decision: 'candidate' }
          }))}>
            <option value="">Unassigned</option>
            {bible.characters.map(character => <option key={character.slug} value={character.slug}>{character.name}</option>)}
          </select>
        </label>
        <label>Review
          <select value={assignments[image.sha256]?.decision ?? 'unreviewed'} onChange={event => setAssignments(old => ({
            ...old, [image.sha256]: { characterSlug: old[image.sha256]?.characterSlug ?? '', decision: event.target.value as Assignment['decision'] }
          }))}>
            <option value="unreviewed">Unreviewed</option>
            <option value="candidate">Candidate (not approved)</option>
            <option value="reject">Not a character portrait</option>
          </select>
        </label>
        </>}
      </article>)}
      <button type="button" onClick={downloadMapping}>Export draft mapping JSON</button>
    </>}
  </section>;
}
