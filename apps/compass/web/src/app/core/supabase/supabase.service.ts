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

    this.clientInstance ??= createClient(
      environment.supabaseUrl,
      environment.supabasePublishableKey
    );
    return this.clientInstance;
  }
}
