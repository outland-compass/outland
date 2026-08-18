import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
	{ path: 'sign-in', loadComponent: () => import('./features/sign-in/sign-in.page') },
	{ path: 'radar', canActivate: [authGuard], loadComponent: () => import('./features/radar/radar.page') },
	{ path: 'candidates/:id', canActivate: [authGuard], loadComponent: () => import('./features/candidate/candidate.page') },
	{ path: 'compare', canActivate: [authGuard], loadComponent: () => import('./features/compare/compare.page') },
	{ path: 'due-diligence', canActivate: [authGuard], loadComponent: () => import('./features/due-diligence/due-diligence.page') },
	{ path: 'worlds', canActivate: [authGuard], loadComponent: () => import('./features/worlds/worlds.page') },
	{ path: '', pathMatch: 'full', redirectTo: 'radar' },
	{ path: '**', redirectTo: 'radar' }
];
