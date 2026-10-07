'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export function StudioAccessGate() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setPending(true);

    try {
      const form = new FormData(event.currentTarget);
      const response = await fetch('/api/access', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: form.get('key') })
      });

      if (response.ok) {
        router.replace('/studio');
        router.refresh();
        return;
      }

      const result = await response.json().catch(() => null) as { error?: string } | null;
      setError(result?.error ?? 'Access denied.');
    } catch {
      setError('Studio access is temporarily unavailable.');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="gate">
      <section className="card">
        <div className="portal"><i/><i/></div>
        <p className="brand">SIDE<span>WORLD</span></p>
        <p className="eyebrow">Studio V0-D</p>
        <h1>Author the canon.<br/>Control the context.</h1>
        <p className="muted">Private authoring workspace.</p>
        <form onSubmit={submit} className="studioAccessForm">
          <label htmlFor="key">Studio access key</label>
          <input id="key" name="key" type="password" autoComplete="current-password" required />
          <button className="button" type="submit" disabled={pending}>
            {pending ? 'Opening…' : 'Open Studio'}
          </button>
          <p className="formMessage" role="status">{error}</p>
        </form>
      </section>
    </main>
  );
}
