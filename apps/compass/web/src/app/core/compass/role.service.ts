import { Injectable, signal } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { SupabaseService } from '../supabase/supabase.service';

export type AppRole = 'OWNER' | 'ADMIN' | 'ANALYST' | 'ADVISOR' | 'VIEWER';

@Injectable({ providedIn: 'root' })
export class RoleService {
  readonly roles = signal<AppRole[]>([]);
  constructor(private readonly auth: AuthService, private readonly supabase: SupabaseService) {}
  get canAnalyze() { return this.roles().some((role) => ['OWNER', 'ADMIN', 'ANALYST'].includes(role)); }
  get canEvidence() { return this.roles().some((role) => ['OWNER', 'ADMIN', 'ANALYST', 'ADVISOR'].includes(role)); }
  async load(): Promise<void> {
    const userId = this.auth.session()?.user.id;
    if (!userId || !this.supabase.isConfigured) return;
    const { data, error } = await this.supabase.client.from('user_roles').select('role').eq('user_id', userId);
    if (error) throw new Error(error.message);
    this.roles.set((data ?? []).map((row) => row.role));
  }
}