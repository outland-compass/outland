import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  { path: '', pathMatch: 'full', loadComponent: () => import('./features/home/home.page') },
  { path: 'rafter', loadComponent: () => import('./features/rafter/rafter.page') },
  { path: 'sign-in', loadComponent: () => import('./features/sign-in/sign-in.page') },
  {
    path: '',
    canActivate: [authGuard],
    loadComponent: () => import('./core/layout/compass-layout.component'),
    children: [
      { path: 'radar', loadComponent: () => import('./features/radar/radar.page') },
      { path: 'candidates/:id', loadComponent: () => import('./features/candidate/candidate.page') },
      { path: 'compare', loadComponent: () => import('./features/compare/compare.page') },
      { path: 'due-diligence', loadComponent: () => import('./features/due-diligence/due-diligence.page') },
      { path: 'worlds', loadComponent: () => import('./features/worlds/worlds.page') }
    ]
  },
  { path: '**', redirectTo: '' }
];
