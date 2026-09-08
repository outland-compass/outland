'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export function AccessGate() {
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
        router.replace('/explore');
        router.refresh();
        return;
      }

      const result = await response.json().catch(() => null) as { error?: string } | null;
      setError(result?.error ?? 'That key did not open anything.');
    } catch {
      setError('The door did not answer. Try again.');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="gate">
      <div className="gateBackdrop" aria-hidden="true"><span className="signal" /></div>
      <section className="gatePanel">
        <div className="waveMark" aria-hidden="true"><span /><span /></div>
        <p className="wordmark">OUTLAND</p>
        <p className="eyebrow">Access restricted</p>
        <p className="gatePrompt">If you were given a key, use it.</p>
        <form onSubmit={submit} className="gateForm">
          <label htmlFor="key">Explorer key</label>
          <input id="key" name="key" autoComplete="off" autoCapitalize="none" required />
          <button type="submit" disabled={pending}>{pending ? 'Opening…' : 'Enter key'}</button>
          <p className="formMessage" role="status">{error}</p>
        </form>
      </section>
    </main>
  );
}
