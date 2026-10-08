'use client';

import { FormEvent, useState } from 'react';

type Entity = 'location' | 'locationFact' | 'source' | 'factSource';

async function save(entity: Entity, input: Record<string, unknown>) {
  const response = await fetch('/api/studio/write', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ entity, input })
  });
  const result = await response.json().catch(() => null) as { id?: string; error?: string } | null;
  if (!response.ok || !result?.id) throw new Error(result?.error ?? 'Save failed');
  return result.id;
}

export function CityKnowledgeEditor({ cityId }: { cityId: string }) {
  const [locationId, setLocationId] = useState('');
  const [factId, setFactId] = useState('');
  const [sourceId, setSourceId] = useState('');
  const [message, setMessage] = useState('');

  function submit(entity: Entity, onSaved?: (id: string) => void) {
    return async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      setMessage('');
      try {
        const input = Object.fromEntries(new FormData(event.currentTarget).entries());
        const id = await save(entity, input);
        onSaved?.(id);
        setMessage(`${entity} saved · ${id}`);
      } catch (error) {
        setMessage(error instanceof Error ? error.message : 'Save failed');
      }
    };
  }

  return (
    <section className="authoringStack">
      <p className="formMessage" role="status">{message}</p>

      <form className="authoringPanel" onSubmit={submit('location', setLocationId)}>
        <p className="eyebrow">Location</p>
        <input name="id" placeholder="Existing UUID (optional)" />
        <input name="cityId" type="hidden" value={cityId} />
        <div className="formGrid">
          <input name="slug" placeholder="location-slug" required />
          <input name="name" placeholder="Location name" required />
          <input name="locationType" defaultValue="poi" placeholder="Location type" required />
          <select name="verificationStatus" defaultValue="unverified">
            <option value="unverified">unverified</option>
            <option value="partially_verified">partially verified</option>
            <option value="verified">verified</option>
            <option value="disputed">disputed</option>
          </select>
          <input name="latitude" type="number" step="any" placeholder="Latitude" required />
          <input name="longitude" type="number" step="any" placeholder="Longitude" required />
          <input name="addressText" placeholder="Address (optional)" />
          <select name="publicAccess" defaultValue="">
            <option value="">access unknown</option>
            <option value="true">public access</option>
            <option value="false">not public</option>
          </select>
        </div>
        <button className="button" type="submit">Save location</button>
        {locationId && <code>{locationId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={submit('locationFact', setFactId)}>
        <p className="eyebrow">Fact</p>
        <input name="id" placeholder="Existing UUID (optional)" />
        <input name="cityId" type="hidden" value={cityId} />
        <input name="locationId" value={locationId} onChange={(e) => setLocationId(e.target.value)} placeholder="Location UUID (optional)" />
        <div className="formGrid">
          <input name="factKey" placeholder="stable-fact-key" required />
          <input name="factType" defaultValue="general" placeholder="Fact type" required />
          <select name="verificationStatus" defaultValue="unverified">
            <option value="unverified">unverified</option>
            <option value="partially_verified">partially verified</option>
            <option value="verified">verified</option>
            <option value="disputed">disputed</option>
          </select>
          <input name="confidence" type="number" min="0" max="1" step="0.01" placeholder="Confidence 0–1" />
        </div>
        <textarea name="statement" placeholder="Factual statement" required />
        <button className="button" type="submit">Save fact</button>
        {factId && <code>{factId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={submit('source', setSourceId)}>
        <p className="eyebrow">Source</p>
        <input name="id" placeholder="Existing UUID (optional)" />
        <div className="formGrid">
          <input name="title" placeholder="Source title" required />
          <input name="publisher" placeholder="Publisher" />
          <input name="url" type="url" placeholder="https://…" />
          <input name="sourceType" defaultValue="official" placeholder="Source type" required />
          <input name="publishedAt" type="datetime-local" />
          <input name="trustTier" placeholder="Trust tier" />
        </div>
        <button className="button" type="submit">Save source</button>
        {sourceId && <code>{sourceId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={submit('factSource')}>
        <p className="eyebrow">Evidence link</p>
        <input name="factId" value={factId} onChange={(e) => setFactId(e.target.value)} placeholder="Fact UUID" required />
        <input name="sourceId" value={sourceId} onChange={(e) => setSourceId(e.target.value)} placeholder="Source UUID" required />
        <select name="supportType" defaultValue="supports">
          <option value="supports">supports</option>
          <option value="contradicts">contradicts</option>
          <option value="context">context</option>
        </select>
        <textarea name="note" placeholder="Evidence note (optional)" />
        <button className="button" type="submit">Link evidence</button>
      </form>
    </section>
  );
}
