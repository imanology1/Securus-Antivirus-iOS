import React from 'react';
import { NavLink } from 'react-router-dom';

/* ── SVG icon helpers ── */
const icons = {
  dashboard: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <rect x="14" y="14" width="7" height="7" rx="1" />
    </svg>
  ),
  analytics: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 3v18h18" />
      <path d="M18 9l-5 5-2-2-4 4" />
    </svg>
  ),
  config: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
    </svg>
  ),
  billing: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <rect x="1" y="4" width="22" height="16" rx="2" />
      <line x1="1" y1="10" x2="23" y2="10" />
    </svg>
  ),
  docs: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="16" y1="13" x2="8" y2="13" />
      <line x1="16" y1="17" x2="8" y2="17" />
      <polyline points="10 9 9 9 8 9" />
    </svg>
  ),
  external: (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" />
      <polyline points="15 3 21 3 21 9" />
      <line x1="10" y1="14" x2="21" y2="3" />
    </svg>
  ),
};

const navItems = [
  { to: '/', label: 'Dashboard', icon: icons.dashboard },
  { to: '/analytics', label: 'Analytics', icon: icons.analytics },
  { to: '/configuration', label: 'Configuration', icon: icons.config },
  { to: '/billing', label: 'Billing', icon: icons.billing },
];

const styles: Record<string, React.CSSProperties> = {
  sidebar: {
    position: 'fixed',
    top: 0,
    left: 0,
    bottom: 0,
    width: 'var(--sidebar-width, 240px)',
    backgroundColor: 'var(--color-surface)',
    borderRight: '1px solid var(--color-border)',
    display: 'flex',
    flexDirection: 'column',
    zIndex: 40,
    overflowY: 'auto',
  },
  logoArea: {
    height: 'var(--header-height, 64px)',
    display: 'flex',
    alignItems: 'center',
    padding: '0 24px',
    borderBottom: '1px solid var(--color-border)',
    gap: '10px',
    flexShrink: 0,
  },
  logoMark: {
    width: 32,
    height: 32,
    borderRadius: '8px',
    background: 'linear-gradient(135deg, #3b82f6, #10b981)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#fff',
    fontWeight: 800,
    fontSize: '14px',
    flexShrink: 0,
  },
  logoText: {
    fontSize: '18px',
    fontWeight: 700,
    color: 'var(--color-text-primary)',
    letterSpacing: '-0.02em',
  },
  nav: {
    flex: 1,
    padding: '16px 12px',
    display: 'flex',
    flexDirection: 'column',
    gap: '2px',
  },
  sectionLabel: {
    fontSize: '11px',
    fontWeight: 600,
    textTransform: 'uppercase' as const,
    letterSpacing: '0.05em',
    color: 'var(--color-text-muted)',
    padding: '16px 12px 8px',
  },
  navLink: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '10px 12px',
    borderRadius: '8px',
    color: 'var(--color-text-secondary)',
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: 500,
    transition: 'all 150ms ease',
    cursor: 'pointer',
  },
  footer: {
    padding: '16px 12px',
    borderTop: '1px solid var(--color-border)',
    flexShrink: 0,
  },
  version: {
    fontSize: '11px',
    color: 'var(--color-text-muted)',
    textAlign: 'center' as const,
    padding: '4px 0',
  },
};

const Sidebar: React.FC = () => {
  return (
    <aside style={styles.sidebar}>
      {/* Logo */}
      <div style={styles.logoArea}>
        <div style={styles.logoMark}>S</div>
        <span style={styles.logoText}>Securus</span>
      </div>

      {/* Navigation */}
      <nav style={styles.nav}>
        <div style={styles.sectionLabel}>Main</div>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            style={({ isActive }) => ({
              ...styles.navLink,
              backgroundColor: isActive
                ? 'var(--color-primary-light)'
                : 'transparent',
              color: isActive
                ? 'var(--color-primary)'
                : 'var(--color-text-secondary)',
            })}
            onMouseEnter={(e) => {
              const el = e.currentTarget;
              if (!el.classList.contains('active')) {
                el.style.backgroundColor = 'var(--color-bg-hover)';
              }
            }}
            onMouseLeave={(e) => {
              const el = e.currentTarget;
              if (!el.classList.contains('active')) {
                el.style.backgroundColor = '';
              }
            }}
          >
            {item.icon}
            {item.label}
          </NavLink>
        ))}

        <div style={styles.sectionLabel}>Resources</div>
        <a
          href="https://docs.securus.dev"
          target="_blank"
          rel="noopener noreferrer"
          style={styles.navLink}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = 'var(--color-bg-hover)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = '';
          }}
        >
          {icons.docs}
          <span style={{ flex: 1 }}>Documentation</span>
          {icons.external}
        </a>
      </nav>

      {/* Footer */}
      <div style={styles.footer}>
        <div style={styles.version}>Securus Dashboard v1.0.0</div>
      </div>
    </aside>
  );
};

export default Sidebar;
