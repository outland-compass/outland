'use client';
import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';

export default function ResetPassword() {
  const [token, setToken] = useState('');
  const [message, setMessage] = useState('');
  const [pending, setPending] = useState(false);
  useEffect(() => {
    const hash = new URLSearchParams(window.location.hash.slice(1));
    if (hash.get('type') === 'recovery') setToken(hash.get('access_token') || '');
    window.history.replaceState(null, '', window.location.pathname);
  }, []);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    const form = new FormData(event.currentTarget);
    try {
      const response = await fetch('/api/auth/update-password', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, password: form.get('password') })
      });
      setMessage(response.ok ? 'Password updated. You can now sign in.' : 'Reset link expired or invalid.');
      if (response.ok) setToken('');
    } catch { setMessage('Password reset unavailable.'); }
    finally { setPending(false); }
  }
  return <main className="gate"><section className="card">
    <p className="brand">SIDE<span>WORLD</span></p>
    <h1>Reset password</h1>
    {token ? <form className="studioAccessForm" onSubmit={submit}>
      <label htmlFor="password">New password (12+ characters)</label>
      <input id="password" name="password" type="password" minLength={12} autoComplete="new-password" required />
      <button className="button" type="submit" disabled={pending}>Update password</button>
    </form> : <p>Open a valid password reset link from your email.</p>}
    <p role="status">{message}</p><Link href="/">Back to sign in</Link>
  </section></main>;
}
