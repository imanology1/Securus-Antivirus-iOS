import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/slices/authSlice';
import Button from '@/components/Common/Button';

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'var(--color-bg-primary)',
    padding: '24px',
  },
  container: {
    width: '100%',
    maxWidth: '420px',
  },
  logoRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '12px',
    marginBottom: '32px',
  },
  logoMark: {
    width: 40,
    height: 40,
    borderRadius: '10px',
    background: 'linear-gradient(135deg, #3b82f6, #10b981)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#fff',
    fontWeight: 800,
    fontSize: '18px',
  },
  logoText: {
    fontSize: '24px',
    fontWeight: 700,
    color: 'var(--color-text-primary)',
    letterSpacing: '-0.03em',
  },
  card: {
    backgroundColor: 'var(--color-surface)',
    border: '1px solid var(--color-border)',
    borderRadius: '16px',
    padding: '32px',
    boxShadow: 'var(--shadow-xl)',
  },
  heading: {
    fontSize: '20px',
    fontWeight: 700,
    color: 'var(--color-text-primary)',
    marginBottom: '4px',
    textAlign: 'center' as const,
  },
  subheading: {
    fontSize: '14px',
    color: 'var(--color-text-secondary)',
    marginBottom: '28px',
    textAlign: 'center' as const,
  },
  form: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '20px',
  },
  fieldGroup: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '6px',
  },
  label: {
    fontSize: '13px',
    fontWeight: 500,
    color: 'var(--color-text-secondary)',
  },
  input: {
    padding: '10px 14px',
    borderRadius: '10px',
    fontSize: '14px',
  },
  error: {
    backgroundColor: 'var(--color-danger-light)',
    border: '1px solid rgba(239, 68, 68, 0.3)',
    borderRadius: '10px',
    padding: '12px 16px',
    fontSize: '13px',
    color: '#f87171',
  },
  footer: {
    textAlign: 'center' as const,
    marginTop: '24px',
    fontSize: '13px',
    color: 'var(--color-text-secondary)',
  },
  link: {
    color: 'var(--color-primary)',
    fontWeight: 600,
  },
};

const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login, isLoading, error, isAuthenticated, clearError } =
    useAuthStore();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) navigate('/', { replace: true });
  }, [isAuthenticated, navigate]);

  useEffect(() => {
    clearError();
  }, [clearError]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login(email, password);
      navigate('/', { replace: true });
    } catch {
      // error is set in store
    }
  };

  return (
    <div style={styles.page}>
      <div style={styles.container}>
        <div style={styles.logoRow}>
          <div style={styles.logoMark}>S</div>
          <span style={styles.logoText}>Securus</span>
        </div>

        <div style={styles.card} className="fade-in">
          <h1 style={styles.heading}>Welcome back</h1>
          <p style={styles.subheading}>
            Sign in to your developer dashboard
          </p>

          {error && <div style={styles.error}>{error}</div>}

          <form onSubmit={handleSubmit} style={styles.form}>
            <div style={styles.fieldGroup}>
              <label style={styles.label}>Email address</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@company.com"
                required
                autoComplete="email"
                style={styles.input}
              />
            </div>

            <div style={styles.fieldGroup}>
              <label style={styles.label}>Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter your password"
                required
                autoComplete="current-password"
                style={styles.input}
              />
            </div>

            <Button
              type="submit"
              variant="primary"
              size="lg"
              fullWidth
              loading={isLoading}
            >
              Sign In
            </Button>
          </form>

          <div style={styles.footer}>
            Don't have an account?{' '}
            <Link to="/register" style={styles.link}>
              Create one
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
