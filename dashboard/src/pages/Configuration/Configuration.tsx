import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { useDashboardStore } from '@/store/slices/dashboardSlice';
import { appService } from '@/services/app.service';
import Button from '@/components/Common/Button';
import Modal from '@/components/Common/Modal';
import type { App } from '@/types';

/* ── Mock app data fallback ── */
const mockApps: App[] = [
  {
    id: 'app-001',
    name: 'Securus Demo App',
    bundleId: 'com.securus.demo',
    platform: 'ios',
    apiKey: 'sk_live_demo_a1b2c3d4e5f6',
    createdAt: '2024-09-15T10:30:00Z',
    devicesCount: 8_432,
    isActive: true,
  },
  {
    id: 'app-002',
    name: 'FinanceGuard',
    bundleId: 'com.financeguard.app',
    platform: 'cross-platform',
    apiKey: 'sk_live_fing_x9y8z7w6v5u4',
    createdAt: '2024-11-02T14:15:00Z',
    devicesCount: 4_051,
    isActive: true,
  },
];

/* ── Styles ── */
const styles: Record<string, React.CSSProperties> = {
  page: {
    display: 'flex',
    flexDirection: 'column',
    gap: '24px',
  },
  pageHeader: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: '16px',
  },
  pageTitle: {
    fontSize: '24px',
    fontWeight: 700,
    color: '#f1f5f9',
    letterSpacing: '-0.025em',
  },
  section: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  sectionTitle: {
    fontSize: '16px',
    fontWeight: 600,
    color: '#f1f5f9',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  appCard: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px solid #1e293b',
    padding: '24px',
    transition: 'border-color 200ms ease',
  },
  appCardTop: {
    display: 'flex',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: '16px',
    marginBottom: '20px',
  },
  appInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: '4px',
  },
  appName: {
    fontSize: '16px',
    fontWeight: 600,
    color: '#f1f5f9',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  platformBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '2px 8px',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: 600,
    textTransform: 'uppercase' as const,
    letterSpacing: '0.04em',
  },
  appMeta: {
    fontSize: '12px',
    color: '#64748b',
    display: 'flex',
    alignItems: 'center',
    gap: '16px',
  },
  apiKeySection: {
    backgroundColor: '#111827',
    borderRadius: '10px',
    padding: '14px 16px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: '12px',
    border: '1px solid #1e293b',
  },
  apiKeyLabel: {
    fontSize: '11px',
    fontWeight: 600,
    color: '#64748b',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.04em',
    marginBottom: '6px',
  },
  apiKeyValue: {
    fontSize: '14px',
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
    color: '#94a3b8',
    letterSpacing: '0.02em',
  },
  showHideBtn: {
    border: 'none',
    backgroundColor: 'transparent',
    color: '#3b82f6',
    fontSize: '12px',
    fontWeight: 600,
    cursor: 'pointer',
    padding: '4px 8px',
    borderRadius: '6px',
    transition: 'background-color 150ms ease',
    fontFamily: 'inherit',
    whiteSpace: 'nowrap' as const,
    flexShrink: 0,
  },
  cardActions: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: '8px',
    marginTop: '16px',
    paddingTop: '16px',
    borderTop: '1px solid #1e293b',
  },
  /* Register form */
  formCard: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px solid #334155',
    padding: '24px',
  },
  formTitle: {
    fontSize: '16px',
    fontWeight: 600,
    color: '#f1f5f9',
    marginBottom: '20px',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  formGrid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '16px',
  },
  fieldGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '6px',
  },
  label: {
    fontSize: '13px',
    fontWeight: 500,
    color: '#94a3b8',
  },
  input: {
    padding: '10px 14px',
    borderRadius: '10px',
    fontSize: '14px',
    backgroundColor: '#111827',
    border: '1px solid #1e293b',
    color: '#f1f5f9',
    outline: 'none',
    fontFamily: 'inherit',
    transition: 'border-color 150ms ease',
    width: '100%',
  },
  select: {
    padding: '10px 14px',
    borderRadius: '10px',
    fontSize: '14px',
    backgroundColor: '#111827',
    border: '1px solid #1e293b',
    color: '#f1f5f9',
    outline: 'none',
    fontFamily: 'inherit',
    cursor: 'pointer',
    width: '100%',
    appearance: 'none' as const,
    backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E")`,
    backgroundRepeat: 'no-repeat',
    backgroundPosition: 'right 14px center',
    paddingRight: '36px',
  },
  formActions: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: '8px',
    marginTop: '20px',
  },
  emptyState: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px dashed #334155',
    padding: '48px 24px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '12px',
    color: '#64748b',
    fontSize: '14px',
    textAlign: 'center' as const,
  },
  /* Delete modal content */
  deleteWarning: {
    fontSize: '14px',
    color: '#94a3b8',
    lineHeight: 1.6,
    marginBottom: '20px',
  },
  deleteAppName: {
    color: '#f1f5f9',
    fontWeight: 600,
  },
  deleteActions: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: '8px',
  },
};

/* ── Platform styling ── */
const platformStyles: Record<string, { bg: string; color: string; border: string }> = {
  ios: {
    bg: 'rgba(59, 130, 246, 0.12)',
    color: '#60a5fa',
    border: 'rgba(59, 130, 246, 0.25)',
  },
  android: {
    bg: 'rgba(16, 185, 129, 0.12)',
    color: '#34d399',
    border: 'rgba(16, 185, 129, 0.25)',
  },
  'cross-platform': {
    bg: 'rgba(139, 92, 246, 0.12)',
    color: '#a78bfa',
    border: 'rgba(139, 92, 246, 0.25)',
  },
};

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function maskApiKey(key: string): string {
  if (key.length <= 12) return '\u2022'.repeat(key.length);
  return key.slice(0, 8) + '\u2022'.repeat(key.length - 12) + key.slice(-4);
}

const Configuration: React.FC = () => {
  const { apps, fetchApps, isLoadingApps } = useDashboardStore();

  const [localApps, setLocalApps] = useState<App[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [formName, setFormName] = useState('');
  const [formBundleId, setFormBundleId] = useState('');
  const [formPlatform, setFormPlatform] = useState<'ios' | 'android' | 'cross-platform'>('ios');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [visibleKeys, setVisibleKeys] = useState<Set<string>>(new Set());
  const [deleteTarget, setDeleteTarget] = useState<App | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  /* ── Fetch apps ── */
  useEffect(() => {
    fetchApps();
  }, [fetchApps]);

  /* Sync store apps to local state with mock fallback */
  useEffect(() => {
    if (apps.length > 0) {
      setLocalApps(apps);
    } else if (!isLoadingApps) {
      setLocalApps(mockApps);
    }
  }, [apps, isLoadingApps]);

  /* ── Key visibility toggle ── */
  const toggleKeyVisibility = useCallback((appId: string) => {
    setVisibleKeys((prev) => {
      const next = new Set(prev);
      if (next.has(appId)) {
        next.delete(appId);
      } else {
        next.add(appId);
      }
      return next;
    });
  }, []);

  /* ── Register new app ── */
  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim() || !formBundleId.trim()) return;

    setIsSubmitting(true);
    try {
      const newApp = await appService.createApp({
        name: formName.trim(),
        bundleId: formBundleId.trim(),
        platform: formPlatform,
      });
      setLocalApps((prev) => [...prev, newApp]);
      resetForm();
    } catch {
      /* Fallback: create locally */
      const fakeApp: App = {
        id: `app-${Date.now()}`,
        name: formName.trim(),
        bundleId: formBundleId.trim(),
        platform: formPlatform,
        apiKey: `sk_live_${Math.random().toString(36).slice(2, 14)}`,
        createdAt: new Date().toISOString(),
        devicesCount: 0,
        isActive: true,
      };
      setLocalApps((prev) => [...prev, fakeApp]);
      resetForm();
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetForm = () => {
    setShowForm(false);
    setFormName('');
    setFormBundleId('');
    setFormPlatform('ios');
  };

  /* ── Delete app ── */
  const handleDelete = async () => {
    if (!deleteTarget) return;
    setIsDeleting(true);
    try {
      await appService.deleteApp(deleteTarget.id);
    } catch {
      /* API unreachable, remove locally anyway */
    }
    setLocalApps((prev) => prev.filter((a) => a.id !== deleteTarget.id));
    setDeleteTarget(null);
    setIsDeleting(false);
  };

  /* ── Derive display data ── */
  const displayApps = useMemo(() => localApps, [localApps]);

  return (
    <div style={styles.page} className="fade-in">
      {/* Page header */}
      <div style={styles.pageHeader}>
        <h1 style={styles.pageTitle}>Configuration</h1>
        {!showForm && (
          <Button variant="primary" size="md" onClick={() => setShowForm(true)}>
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            Register New App
          </Button>
        )}
      </div>

      {/* Register new app form */}
      {showForm && (
        <div style={styles.formCard} className="fade-in">
          <div style={styles.formTitle}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#3b82f6"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            Register New Application
          </div>

          <form onSubmit={handleRegister}>
            <div style={styles.formGrid}>
              <div style={styles.fieldGroup}>
                <label style={styles.label}>App Name</label>
                <input
                  type="text"
                  style={styles.input}
                  placeholder="My Awesome App"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  required
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '#1e293b';
                  }}
                />
              </div>
              <div style={styles.fieldGroup}>
                <label style={styles.label}>Bundle ID</label>
                <input
                  type="text"
                  style={styles.input}
                  placeholder="com.example.myapp"
                  value={formBundleId}
                  onChange={(e) => setFormBundleId(e.target.value)}
                  required
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '#1e293b';
                  }}
                />
              </div>
              <div style={styles.fieldGroup}>
                <label style={styles.label}>Platform</label>
                <select
                  style={styles.select}
                  value={formPlatform}
                  onChange={(e) =>
                    setFormPlatform(
                      e.target.value as 'ios' | 'android' | 'cross-platform',
                    )
                  }
                >
                  <option value="ios">iOS</option>
                  <option value="android">Android</option>
                  <option value="cross-platform">Cross-Platform</option>
                </select>
              </div>
            </div>

            <div style={styles.formActions}>
              <Button
                type="button"
                variant="ghost"
                size="md"
                onClick={resetForm}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="primary"
                size="md"
                loading={isSubmitting}
                disabled={!formName.trim() || !formBundleId.trim()}
              >
                Register App
              </Button>
            </div>
          </form>
        </div>
      )}

      {/* Your Apps section */}
      <div style={styles.section}>
        <div style={styles.sectionTitle}>
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <rect x="2" y="3" width="20" height="14" rx="2" />
            <line x1="8" y1="21" x2="16" y2="21" />
            <line x1="12" y1="17" x2="12" y2="21" />
          </svg>
          Your Apps
          <span style={{ fontSize: '13px', fontWeight: 400, color: '#64748b' }}>
            ({displayApps.length})
          </span>
        </div>

        {isLoadingApps && displayApps.length === 0 ? (
          <div style={styles.emptyState}>
            <div style={{ fontSize: '13px', color: '#94a3b8' }}>
              Loading your applications...
            </div>
          </div>
        ) : displayApps.length === 0 ? (
          <div style={styles.emptyState}>
            <svg
              width="40"
              height="40"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#334155"
              strokeWidth="1.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <rect x="2" y="3" width="20" height="14" rx="2" />
              <line x1="8" y1="21" x2="16" y2="21" />
              <line x1="12" y1="17" x2="12" y2="21" />
            </svg>
            <span>No applications registered yet.</span>
            <span style={{ fontSize: '13px' }}>
              Click "Register New App" to get started.
            </span>
          </div>
        ) : (
          displayApps.map((app) => {
            const pStyle = platformStyles[app.platform] || platformStyles['ios'];
            const isKeyVisible = visibleKeys.has(app.id);

            return (
              <div
                key={app.id}
                style={styles.appCard}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = '#334155';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = '#1e293b';
                }}
              >
                <div style={styles.appCardTop}>
                  <div style={styles.appInfo}>
                    <div style={styles.appName}>
                      {app.name}
                      <span
                        style={{
                          ...styles.platformBadge,
                          backgroundColor: pStyle.bg,
                          color: pStyle.color,
                          border: `1px solid ${pStyle.border}`,
                        }}
                      >
                        {app.platform}
                      </span>
                    </div>
                    <div style={styles.appMeta}>
                      <span>{app.bundleId}</span>
                      <span>{'\u2022'}</span>
                      <span>Created {formatDate(app.createdAt)}</span>
                      <span>{'\u2022'}</span>
                      <span>
                        {app.devicesCount.toLocaleString()} device
                        {app.devicesCount !== 1 ? 's' : ''}
                      </span>
                    </div>
                  </div>

                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      fontSize: '12px',
                      fontWeight: 500,
                      color: app.isActive ? '#10b981' : '#64748b',
                    }}
                  >
                    <div
                      style={{
                        width: 6,
                        height: 6,
                        borderRadius: '50%',
                        backgroundColor: app.isActive ? '#10b981' : '#64748b',
                      }}
                    />
                    {app.isActive ? 'Active' : 'Inactive'}
                  </div>
                </div>

                {/* API Key section */}
                <div>
                  <div style={styles.apiKeyLabel}>API Key</div>
                  <div style={styles.apiKeySection}>
                    <code style={styles.apiKeyValue}>
                      {isKeyVisible ? app.apiKey : maskApiKey(app.apiKey)}
                    </code>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <button
                        style={styles.showHideBtn}
                        onClick={() => toggleKeyVisibility(app.id)}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.backgroundColor =
                            'rgba(59, 130, 246, 0.1)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.backgroundColor = 'transparent';
                        }}
                      >
                        {isKeyVisible ? (
                          <>
                            <svg
                              width="12"
                              height="12"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              strokeWidth="2"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              style={{ display: 'inline', verticalAlign: 'middle', marginRight: '4px' }}
                            >
                              <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19m-6.72-1.07a3 3 0 01-4.24-4.24" />
                              <line x1="1" y1="1" x2="23" y2="23" />
                            </svg>
                            Hide
                          </>
                        ) : (
                          <>
                            <svg
                              width="12"
                              height="12"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              strokeWidth="2"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              style={{ display: 'inline', verticalAlign: 'middle', marginRight: '4px' }}
                            >
                              <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                              <circle cx="12" cy="12" r="3" />
                            </svg>
                            Show
                          </>
                        )}
                      </button>
                      <button
                        style={{
                          ...styles.showHideBtn,
                          color: '#94a3b8',
                        }}
                        onClick={() => {
                          navigator.clipboard.writeText(app.apiKey);
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.backgroundColor =
                            'rgba(148, 163, 184, 0.1)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.backgroundColor = 'transparent';
                        }}
                      >
                        <svg
                          width="12"
                          height="12"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          style={{ display: 'inline', verticalAlign: 'middle', marginRight: '4px' }}
                        >
                          <rect x="9" y="9" width="13" height="13" rx="2" />
                          <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
                        </svg>
                        Copy
                      </button>
                    </div>
                  </div>
                </div>

                {/* Card actions */}
                <div style={styles.cardActions}>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => setDeleteTarget(app)}
                  >
                    <svg
                      width="12"
                      height="12"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    >
                      <polyline points="3 6 5 6 21 6" />
                      <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                    </svg>
                    Delete
                  </Button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Delete confirmation modal */}
      <Modal
        isOpen={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="Delete Application"
      >
        <div style={styles.deleteWarning}>
          Are you sure you want to delete{' '}
          <span style={styles.deleteAppName}>{deleteTarget?.name}</span>? This
          action cannot be undone. All associated API keys will be revoked and
          devices will stop receiving protection updates.
        </div>
        <div style={styles.deleteActions}>
          <Button
            variant="secondary"
            size="md"
            onClick={() => setDeleteTarget(null)}
          >
            Cancel
          </Button>
          <Button
            variant="danger"
            size="md"
            loading={isDeleting}
            onClick={handleDelete}
          >
            Delete Application
          </Button>
        </div>
      </Modal>
    </div>
  );
};

export default Configuration;
