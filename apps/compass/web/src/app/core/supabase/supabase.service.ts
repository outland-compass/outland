import { Injectable } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class SupabaseService {
  private clientInstance?: SupabaseClient;

  get isConfigured(): boolean {
    return Boolean(environment.supabaseUrl && environment.supabasePublishableKey);
  }

  get client(): SupabaseClient {
    if (!this.isConfigured) {
      throw new Error('Supabase URL and publishable key must be configured.');
    }

    // Auth redirects (password recovery) are consumed by AuthService, which removes the tokens from
    // the address bar without leaving them in a history entry.
    this.clientInstance ??= createClient(
      environment.supabaseUrl,
      environment.supabasePublishableKey,
      { auth: { detectSessionInUrl: false } }
    );
    return this.clientInstance;
  }
}
