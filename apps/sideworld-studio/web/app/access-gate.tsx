'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export function StudioAccessGate() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [pending, setPending] = useState(false);
  const [resetMode, setResetMode] = useState(false);
  const [email, setEmail] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setPending(true);
    try {
      const form = new FormData(event.currentTarget);
      const response = await fetch(resetMode ? '/api/auth/reset' : '/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(resetMode
          ? { email }
          : { email, password: form.get('password') })
      });
      if (response.ok) {
        if (resetMode) {
          setError('If the account exists, check your email.');
        } else {
          router.replace('/studio');
          router.refresh();
        }
        return;
      }
      const result = await response.json().catch(() => null) as { error?: string } | null;
      setError(result?.error ?? 'Sign-in unavailable.');
    } catch {
      setError('Studio is temporarily unavailable.');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="gate">
      <section className="card">
        <div className="portal"><i/><i/></div>
        <p className="brand">SIDE<span>WORLD</span></p>
        <p className="eyebrow">Studio Auth V1</p>
        <h1>Author the canon. Control the context.</h1>
        <p className="muted">Private workspace for authorized editors.</p>
        <form onSubmit={submit} className="studioAccessForm">
          <label htmlFor="email">Email</label>
          <input id="email" name="email" type="email" autoComplete="email" value={email} onChange={event => setEmail(event.target.value)} required />
          {!resetMode && <>
            <label htmlFor="password">Password</label>
            <input id="password" name="password" type="password" autoComplete="current-password" required />
          </>}
          <button className="button" type="submit" disabled={pending}>
            {pending ? 'Please wait…' : resetMode ? 'Send reset email' : 'Sign in'}
          </button>
          <button type="button" onClick={() => { setResetMode(!resetMode); setError(''); }}>
            {resetMode ? 'Back to sign in' : 'Forgot password?'}
          </button>
          <p className="formMessage" role="status">{error}</p>
        </form>
      </section>
    </main>
  );
}
