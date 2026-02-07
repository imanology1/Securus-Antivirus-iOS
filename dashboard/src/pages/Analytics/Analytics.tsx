import React, { useEffect, useMemo } from 'react';
import { useDashboardStore } from '@/store/slices/dashboardSlice';
import TimeSeriesChart from '@/components/Charts/TimeSeriesChart';
import ThreatDistributionChart from '@/components/Charts/ThreatDistributionChart';
import { ThreatType } from '@/types';
import type { TimelineDataPoint, ThreatDistribution } from '@/types';

/* ── Mock data fallback ── */
function mockTimeline(range: '24h' | '7d' | '30d'): TimelineDataPoint[] {
  const points = range === '24h' ? 24 : range === '7d' ? 7 : 30;
  const now = Date.now();
  const interval =
    range === '24h' ? 3_600_000 : 86_400_000;
  return Array.from({ length: points }, (_, i) => ({
    timestamp: new Date(now - (points - 1 - i) * interval).toISOString(),
    count: Math.floor(30 + Math.random() * 120),
  }));
}

const mockDistribution: ThreatDistribution[] = [
  { threatType: ThreatType.NETWORK_INTRUSION, count: 342, percentage: 27.4 },
  { threatType: ThreatType.MALWARE, count: 267, percentage: 21.4 },
  { threatType: ThreatType.PHISHING, count: 198, percentage: 15.9 },
  { threatType: ThreatType.DATA_EXFILTRATION, count: 143, percentage: 11.5 },
  { threatType: ThreatType.MAN_IN_THE_MIDDLE, count: 98, percentage: 7.9 },
  { threatType: ThreatType.CODE_INJECTION, count: 76, percentage: 6.1 },
  { threatType: ThreatType.JAILBREAK, count: 54, percentage: 4.3 },
  { threatType: ThreatType.PRIVILEGE_ESCALATION, count: 34, percentage: 2.7 },
  { threatType: ThreatType.RANSOMWARE, count: 21, percentage: 1.7 },
  { threatType: ThreatType.SPYWARE, count: 14, percentage: 1.1 },
];

/* ── Human-readable labels ── */
const threatTypeLabels: Record<string, string> = {
  [ThreatType.NETWORK_INTRUSION]: 'Network Anomaly',
  [ThreatType.MALWARE]: 'Malware',
  [ThreatType.PHISHING]: 'Phishing',
  [ThreatType.JAILBREAK]: 'Jailbreak',
  [ThreatType.DATA_EXFILTRATION]: 'Data Exfiltration',
  [ThreatType.MAN_IN_THE_MIDDLE]: 'MitM Attack',
  [ThreatType.CODE_INJECTION]: 'Code Injection',
  [ThreatType.PRIVILEGE_ESCALATION]: 'Privilege Escalation',
  [ThreatType.RANSOMWARE]: 'Ransomware',
  [ThreatType.SPYWARE]: 'Spyware',
};

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
  timeRangeGroup: {
    display: 'flex',
    gap: '4px',
    backgroundColor: '#111827',
    borderRadius: '10px',
    padding: '4px',
    border: '1px solid #1e293b',
  },
  timeBtn: {
    padding: '7px 16px',
    borderRadius: '7px',
    border: 'none',
    fontSize: '13px',
    fontWeight: 500,
    cursor: 'pointer',
    transition: 'all 150ms ease',
    fontFamily: 'inherit',
    letterSpacing: '-0.01em',
  },
  timeBtnActive: {
    backgroundColor: '#3b82f6',
    color: '#fff',
  },
  timeBtnInactive: {
    backgroundColor: 'transparent',
    color: '#94a3b8',
  },
  chartSection: {
    minHeight: '380px',
  },
  bottomRow: {
    display: 'flex',
    gap: '16px',
    minHeight: '400px',
  },
  distributionCol: {
    flex: '0 0 340px',
    minWidth: 0,
  },
  tableCol: {
    flex: 1,
    minWidth: 0,
  },
  tableCard: {
    backgroundColor: '#1a1f2e',
    borderRadius: '16px',
    border: '1px solid #1e293b',
    padding: '20px',
    height: '100%',
    display: 'flex',
    flexDirection: 'column',
  },
  tableTitle: {
    fontSize: '15px',
    fontWeight: 600,
    color: '#f1f5f9',
    marginBottom: '16px',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse' as const,
  },
  th: {
    textAlign: 'left' as const,
    padding: '10px 12px',
    fontSize: '11px',
    fontWeight: 600,
    color: '#64748b',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.05em',
    borderBottom: '1px solid #1e293b',
  },
  td: {
    padding: '12px 12px',
    fontSize: '13px',
    color: '#94a3b8',
    borderBottom: '1px solid rgba(30, 41, 59, 0.5)',
  },
  rankBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 24,
    height: 24,
    borderRadius: '6px',
    fontSize: '12px',
    fontWeight: 600,
  },
  barOuter: {
    width: '100%',
    height: 6,
    borderRadius: 3,
    backgroundColor: '#111827',
    overflow: 'hidden',
  },
  barInner: {
    height: '100%',
    borderRadius: 3,
    transition: 'width 600ms ease',
  },
};

const timeRanges: Array<{ value: '24h' | '7d' | '30d'; label: string }> = [
  { value: '24h', label: '24 Hours' },
  { value: '7d', label: '7 Days' },
  { value: '30d', label: '30 Days' },
];

const barColors = [
  '#3b82f6', '#ef4444', '#f97316', '#8b5cf6', '#06b6d4',
  '#eab308', '#ec4899', '#14b8a6', '#6366f1', '#f43f5e',
];

const Analytics: React.FC = () => {
  const {
    timeline,
    distribution,
    timeRange,
    setTimeRange,
    fetchTimeline,
    fetchDistribution,
    isLoadingTimeline,
    isLoadingDistribution,
  } = useDashboardStore();

  /* ── Initial fetch ── */
  useEffect(() => {
    fetchTimeline();
    fetchDistribution();
  }, [fetchTimeline, fetchDistribution]);

  /* ── Data with fallback ── */
  const displayTimeline = useMemo(() => {
    if (timeline.length > 0) return timeline;
    return mockTimeline(timeRange);
  }, [timeline, timeRange]);

  const displayDistribution = useMemo(() => {
    if (distribution.length > 0) return distribution;
    return mockDistribution;
  }, [distribution]);

  /* Sort distribution by count descending for the table */
  const sortedDistribution = useMemo(
    () => [...displayDistribution].sort((a, b) => b.count - a.count),
    [displayDistribution],
  );

  const maxCount = sortedDistribution[0]?.count ?? 1;

  return (
    <div style={styles.page} className="fade-in">
      {/* Page header with time range selector */}
      <div style={styles.pageHeader}>
        <h1 style={styles.pageTitle}>Analytics</h1>
        <div style={styles.timeRangeGroup}>
          {timeRanges.map((r) => (
            <button
              key={r.value}
              onClick={() => setTimeRange(r.value)}
              style={{
                ...styles.timeBtn,
                ...(timeRange === r.value
                  ? styles.timeBtnActive
                  : styles.timeBtnInactive),
              }}
              onMouseEnter={(e) => {
                if (timeRange !== r.value) {
                  e.currentTarget.style.backgroundColor = '#1e293b';
                  e.currentTarget.style.color = '#f1f5f9';
                }
              }}
              onMouseLeave={(e) => {
                if (timeRange !== r.value) {
                  e.currentTarget.style.backgroundColor = 'transparent';
                  e.currentTarget.style.color = '#94a3b8';
                }
              }}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      {/* Time series chart */}
      <div style={styles.chartSection}>
        {isLoadingTimeline ? (
          <div
            style={{
              backgroundColor: '#1a1f2e',
              borderRadius: '16px',
              border: '1px solid #1e293b',
              height: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#64748b',
              fontSize: '13px',
            }}
          >
            Loading chart data...
          </div>
        ) : (
          <TimeSeriesChart data={displayTimeline} timeRange={timeRange} />
        )}
      </div>

      {/* Distribution chart + Top threats table */}
      <div style={styles.bottomRow}>
        <div style={styles.distributionCol}>
          {isLoadingDistribution ? (
            <div
              style={{
                backgroundColor: '#1a1f2e',
                borderRadius: '16px',
                border: '1px solid #1e293b',
                height: '100%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#64748b',
                fontSize: '13px',
              }}
            >
              Loading distribution...
            </div>
          ) : (
            <ThreatDistributionChart data={displayDistribution} />
          )}
        </div>

        <div style={styles.tableCol}>
          <div style={styles.tableCard}>
            <span style={styles.tableTitle}>Top Threat Types</span>
            <div style={{ flex: 1, overflowY: 'auto' }}>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={{ ...styles.th, width: '40px' }}>#</th>
                    <th style={styles.th}>Threat Type</th>
                    <th style={{ ...styles.th, width: '80px', textAlign: 'right' }}>
                      Count
                    </th>
                    <th style={{ ...styles.th, width: '60px', textAlign: 'right' }}>
                      Share
                    </th>
                    <th style={{ ...styles.th, width: '120px' }}>Volume</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedDistribution.map((d, i) => {
                    const color = barColors[i % barColors.length];
                    const rankBg =
                      i === 0
                        ? 'rgba(239, 68, 68, 0.12)'
                        : i === 1
                          ? 'rgba(249, 115, 22, 0.12)'
                          : i === 2
                            ? 'rgba(245, 158, 11, 0.12)'
                            : 'rgba(100, 116, 139, 0.08)';
                    const rankColor =
                      i === 0
                        ? '#ef4444'
                        : i === 1
                          ? '#f97316'
                          : i === 2
                            ? '#eab308'
                            : '#64748b';

                    return (
                      <tr key={d.threatType}>
                        <td style={styles.td}>
                          <span
                            style={{
                              ...styles.rankBadge,
                              backgroundColor: rankBg,
                              color: rankColor,
                            }}
                          >
                            {i + 1}
                          </span>
                        </td>
                        <td style={{ ...styles.td, color: '#f1f5f9', fontWeight: 500 }}>
                          {threatTypeLabels[d.threatType] || d.threatType}
                        </td>
                        <td
                          style={{
                            ...styles.td,
                            textAlign: 'right',
                            fontVariantNumeric: 'tabular-nums',
                          }}
                        >
                          {d.count.toLocaleString()}
                        </td>
                        <td
                          style={{
                            ...styles.td,
                            textAlign: 'right',
                            fontVariantNumeric: 'tabular-nums',
                          }}
                        >
                          {d.percentage.toFixed(1)}%
                        </td>
                        <td style={styles.td}>
                          <div style={styles.barOuter}>
                            <div
                              style={{
                                ...styles.barInner,
                                width: `${(d.count / maxCount) * 100}%`,
                                backgroundColor: color,
                              }}
                            />
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Analytics;
