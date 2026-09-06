import { Component } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from '../auth/auth.service';

@Component({
  selector: 'app-compass-layout',
  imports: [RouterLink, RouterLinkActive, RouterOutlet],
  templateUrl: './compass-layout.component.html',
  styleUrl: './compass-layout.component.scss'
})
export default class CompassLayoutComponent {
  constructor(private readonly auth: AuthService) {}

  async signOut(): Promise<void> {
    await this.auth.signOut();
  }
}
