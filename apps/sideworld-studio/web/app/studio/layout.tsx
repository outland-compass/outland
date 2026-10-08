import type { ReactNode } from 'react';
import { StudioSidebar } from './studio-sidebar';
import { LogoutButton } from './logout-button';

export default function StudioLayout({ children }: { children: ReactNode }) {
  return <div className="studioLayout">
    <div className="studioNavigation">
      <StudioSidebar />
      <div className="studioSideFooter"><LogoutButton /><p className="phase">PRIVATE AUTHORING</p></div>
    </div>
    <div className="studioContent">{children}</div>
  </div>;
}
