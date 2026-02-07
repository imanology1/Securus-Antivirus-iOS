import React, { useEffect, useRef } from 'react';
import type { ThreatEvent } from '@/types';
import { Severity, ThreatType } from '@/types';

interface ThreatFeedProps {
  threats: ThreatEvent[];
}

/* ── Severity color map ── */
const severityColors: Record<Severity, string> = {
  [Severity.CRITICAL]: '#ef4444',
  [Severity.HIGH]: '#f97316',
  [Severity.MEDIUM]: '#eab308',
  [Severity.LOW]: '#3b82f6',
};

/* ── Human-readable threat type labels ── */
const threatLabels: Record<ThreatType, string> = {
  [ThreatType.MALWARE]: 'Malware',
  [ThreatType.NETWORK_INTRUSION]: 'Network Anomaly',
  [ThreatType.PHISHING]: 'Phishing',
  [ThreatType.JAILBREAK]: 'Jailbreak Detected',
  [ThreatType.DATA_EXFILTRATION]: 'Data Exfiltration',
  [ThreatType.MAN_IN_THE_MIDDLE]: 'MitM Attack',
  [ThreatType.CODE_INJECTION]: 'Code Injection',
  [ThreatType.PRIVILEGE_ESCALATION]: 'Privilege Escalation',
  [ThreatType.RANSOMWARE]: 'Ransomware',
  [ThreatType.SPYWARE]: 'Spyware',
};

/* ── Relative time formatter ── */
function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

/* ── Styles ── */
const styles: Record<string, React.CSSProperties> = {
  container: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px solid #1e293b',
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    minHeight: 0,
    overflow: 'hidden',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '18px 20px',
    borderBottom: '1px solid #1e293b',
    flexShrink: 0,
  },
  headerTitle: {
    fontSize: '15px',
    fontWeight: 600,
    color: '#f1f5f9',
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  liveBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '5px',
    fontSize: '11px',
    fontWeight: 600,
    color: '#10b981',
    backgroundColor: 'rgba(16, 185, 129, 0.1)',
    border: '1px solid rgba(16, 185, 129, 0.2)',
    borderRadius: '20px',
    padding: '2px 10px',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.04em',
  },
  liveDot: {
    width: 5,
    height: 5,
    borderRadius: '50%',
    backgroundColor: '#10b981',
    animation: 'pulse-dot 2s ease-in-out infinite',
  },
  list: {
    flex: 1,
    overflowY: 'auto' as const,
    padding: '4px 0',
  },
  item: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '12px',
    padding: '14px 20px',
    borderBottom: '1px solid rgba(30, 41, 59, 0.5)',
    transition: 'background-color 150ms ease',
    cursor: 'default',
  },
  dotColumn: {
    paddingTop: '4px',
    flexShrink: 0,
  },
  severityDot: {
    width: 8,
    height: 8,
    borderRadius: '50%',
    flexShrink: 0,
  },
  content: {
    flex: 1,
    minWidth: 0,
  },
  topRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: '8px',
    marginBottom: '4px',
  },
  threatType: {
    fontSize: '13px',
    fontWeight: 600,
    color: '#f1f5f9',
    whiteSpace: 'nowrap' as const,
  },
  time: {
    fontSize: '11px',
    color: '#64748b',
    whiteSpace: 'nowrap' as const,
    flexShrink: 0,
  },
  description: {
    fontSize: '12px',
    color: '#94a3b8',
    lineHeight: 1.4,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
  },
  meta: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginTop: '6px',
    fontSize: '11px',
    color: '#64748b',
  },
  metaItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
  },
  skeleton: {
    padding: '14px 20px',
    borderBottom: '1px solid rgba(30, 41, 59, 0.5)',
  },
  skeletonLine: {
    height: '12px',
    borderRadius: '6px',
    background: 'linear-gradient(90deg, #1e293b 25%, #243147 50%, #1e293b 75%)',
    backgroundSize: '200% 100%',
    animation: 'shimmer 1.5s ease-in-out infinite',
  },
  emptyState: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    color: '#64748b',
    fontSize: '13px',
    padding: '40px 20px',
  },
};

const SkeletonItem: React.FC = () => (
  <div style={styles.skeleton}>
    <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
      <div
        style={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          backgroundColor: '#1e293b',
        }}
      />
      <div style={{ flex: 1 }}>
        <div
          style={{
            ...styles.skeletonLine,
            width: '50%',
            marginBottom: '8px',
          }}
        />
        <div style={{ ...styles.skeletonLine, width: '80%' }} />
      </div>
    </div>
  </div>
);

const ThreatFeed: React.FC<ThreatFeedProps> = ({ threats }) => {
  const listRef = useRef<HTMLDivElement>(null);
  const prevCountRef = useRef(threats.length);

  /* Auto-scroll to top when new threats arrive */
  useEffect(() => {
    if (threats.length > prevCountRef.current && listRef.current) {
      listRef.current.scrollTo({ top: 0, behavior: 'smooth' });
    }
    prevCountRef.current = threats.length;
  }, [threats.length]);

  const isLoading = threats.length === 0;

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <span style={styles.headerTitle}>
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
          Live Threat Feed
        </span>
        <span style={styles.liveBadge}>
          <span style={styles.liveDot} />
          Live
        </span>
      </div>

      <div ref={listRef} style={styles.list}>
        {isLoading ? (
          <>
            <SkeletonItem />
            <SkeletonItem />
            <SkeletonItem />
            <SkeletonItem />
            <SkeletonItem />
            <SkeletonItem />
          </>
        ) : (
          threats.map((threat) => (
            <div
              key={threat.id}
              style={styles.item}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(30, 41, 59, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'transparent';
              }}
            >
              <div style={styles.dotColumn}>
                <div
                  style={{
                    ...styles.severityDot,
                    backgroundColor: severityColors[threat.severity],
                    boxShadow: `0 0 6px ${severityColors[threat.severity]}60`,
                  }}
                />
              </div>
              <div style={styles.content}>
                <div style={styles.topRow}>
                  <span style={styles.threatType}>
                    {threatLabels[threat.threatType] || threat.threatType}
                  </span>
                  <span style={styles.time}>{relativeTime(threat.detectedAt)}</span>
                </div>
                <div style={styles.description}>{threat.description}</div>
                <div style={styles.meta}>
                  {threat.country && (
                    <span style={styles.metaItem}>
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" />
                        <circle cx="12" cy="10" r="3" />
                      </svg>
                      {threat.country}
                    </span>
                  )}
                  {threat.sourceIp && (
                    <span style={styles.metaItem}>
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <rect x="2" y="2" width="20" height="8" rx="2" />
                        <rect x="2" y="14" width="20" height="8" rx="2" />
                        <line x1="6" y1="6" x2="6.01" y2="6" />
                        <line x1="6" y1="18" x2="6.01" y2="18" />
                      </svg>
                      {threat.sourceIp}
                    </span>
                  )}
                  {threat.mitigated && (
                    <span
                      style={{
                        ...styles.metaItem,
                        color: '#10b981',
                      }}
                    >
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                        <polyline points="20 6 9 17 4 12" />
                      </svg>
                      Mitigated
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default ThreatFeed;
