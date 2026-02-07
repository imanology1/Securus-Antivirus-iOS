import React from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface LayoutProps {
  children: React.ReactNode;
}

const styles: Record<string, React.CSSProperties> = {
  wrapper: {
    minHeight: '100vh',
    backgroundColor: 'var(--color-bg-primary)',
  },
  main: {
    marginLeft: 'var(--sidebar-width, 240px)',
    paddingTop: 'var(--header-height, 64px)',
    minHeight: '100vh',
  },
  content: {
    padding: '24px',
    maxWidth: '1440px',
  },
};

const Layout: React.FC<LayoutProps> = ({ children }) => {
  return (
    <div style={styles.wrapper}>
      <Sidebar />
      <Header />
      <main style={styles.main}>
        <div style={styles.content}>{children}</div>
      </main>
    </div>
  );
};

export default Layout;
