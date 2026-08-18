import { Injectable, signal } from '@angular/core';
import { Session } from '@supabase/supabase-js';

import { SupabaseService } from '../supabase/supabase.service';

@Injectable({ providedIn: 'root' })
export class AuthService {
  readonly session = signal<Session | null>(null);
  readonly ready = signal(false);
  readonly error = signal<string | null>(null);

  constructor(private readonly supabase: SupabaseService) {}

  async restoreSession(): Promise<void> {
    if (!this.supabase.isConfigured) {
      this.ready.set(true);
      return;
    }

    try {
      const { data, error } = await this.supabase.client.auth.getSession();
      if (error) {
        this.error.set(error.message);
      } else {
        this.session.set(data.session);
        this.supabase.client.auth.onAuthStateChange((_event, nextSession) => {
          this.session.set(nextSession);
        });
      }
    } catch {
      this.error.set('Authentication could not be initialized. Please verify local configuration.');
    } finally {
      this.ready.set(true);
    }
  }

  async signIn(email: string, password: string): Promise<string | null> {
    const { error } = await this.supabase.client.auth.signInWithPassword({ email, password });
    return error?.message ?? null;
  }

  async signOut(): Promise<void> {
    if (this.supabase.isConfigured) {
      await this.supabase.client.auth.signOut();
    }
  }
}
