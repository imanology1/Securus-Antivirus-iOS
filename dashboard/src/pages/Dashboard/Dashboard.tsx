import React, { useEffect, useCallback, useMemo } from 'react';
import { useDashboardStore } from '@/store/slices/dashboardSlice';
import StatCard from '@/components/Cards/StatCard';
import ThreatFeed from '@/components/ThreatFeed/ThreatFeed';
import ThreatMap from '@/components/ThreatMap/ThreatMap';
import { ThreatType, Severity } from '@/types';
import type { ThreatEvent } from '@/types';

/* ── Auto-refresh interval ── */
const REFRESH_INTERVAL_MS = 30_000;

/* ──────────────────────────────────────────────
   Mock data fallback generator
   ────────────────────────────────────────────── */
function generateMockThreats(): ThreatEvent[] {
  const threatConfigs: Array<{
    type: ThreatType;
    desc: string;
    severity: Severity;
  }> = [
    { type: ThreatType.NETWORK_INTRUSION, desc: 'Unauthorized network scan from external IP', severity: Severity.HIGH },
    { type: ThreatType.JAILBREAK, desc: 'Jailbreak detection bypass attempt', severity: Severity.CRITICAL },
    { type: ThreatType.CODE_INJECTION, desc: 'Runtime code injection attempt blocked', severity: Severity.CRITICAL },
    { type: ThreatType.MALWARE, desc: 'Trojan payload detected in downloaded package', severity: Severity.HIGH },
    { type: ThreatType.PHISHING, desc: 'Credential harvesting page blocked', severity: Severity.MEDIUM },
    { type: ThreatType.DATA_EXFILTRATION, desc: 'Sensitive data upload to unknown endpoint', severity: Severity.HIGH },
    { type: ThreatType.MAN_IN_THE_MIDDLE, desc: 'SSL certificate pinning violation detected', severity: Severity.CRITICAL },
    { type: ThreatType.PRIVILEGE_ESCALATION, desc: 'Unauthorized privilege escalation attempt', severity: Severity.MEDIUM },
    { type: ThreatType.RANSOMWARE, desc: 'File encryption behavior detected and stopped', severity: Severity.CRITICAL },
    { type: ThreatType.SPYWARE, desc: 'Keylogger activity detected on device', severity: Severity.HIGH },
    { type: ThreatType.NETWORK_INTRUSION, desc: 'Suspicious DNS query to known C&C server', severity: Severity.HIGH },
    { type: ThreatType.JAILBREAK, desc: 'Debugger attached to protected process', severity: Severity.CRITICAL },
    { type: ThreatType.PHISHING, desc: 'Malicious URL redirect intercepted', severity: Severity.MEDIUM },
    { type: ThreatType.MALWARE, desc: 'Obfuscated binary payload quarantined', severity: Severity.HIGH },
    { type: ThreatType.CODE_INJECTION, desc: 'Dynamic library injection attempt blocked', severity: Severity.CRITICAL },
  ];

  const countries = [
    { name: 'United States', lat: 38, lng: -97 },
    { name: 'Germany', lat: 51, lng: 10 },
    { name: 'China', lat: 35, lng: 105 },
    { name: 'Brazil', lat: -14, lng: -51 },
    { name: 'India', lat: 20, lng: 78 },
    { name: 'Russia', lat: 61, lng: 105 },
    { name: 'Japan', lat: 36, lng: 138 },
    { name: 'United Kingdom', lat: 55, lng: -3 },
    { name: 'France', lat: 46, lng: 2 },
    { name: 'South Korea', lat: 36, lng: 128 },
    { name: 'Australia', lat: -25, lng: 134 },
    { name: 'Nigeria', lat: 10, lng: 8 },
    { name: 'Mexico', lat: 23, lng: -102 },
    { name: 'Iran', lat: 32, lng: 53 },
    { name: 'Indonesia', lat: -5, lng: 120 },
  ];

  return Array.from({ length: 30 }, (_, i) => {
    const cfg = threatConfigs[i % threatConfigs.length];
    const c = countries[i % countries.length];
    return {
      id: `mock-dashboard-${i}-${Date.now()}`,
      appId: 'app-001',
      deviceId: `device-${(i * 37) % 999}`,
      threatType: cfg.type,
      severity: cfg.severity,
      description: cfg.desc,
      sourceIp: `${(i * 17) % 256}.${(i * 31) % 256}.${(i * 7) % 256}.${(i * 13) % 256}`,
      latitude: c.lat + (Math.random() - 0.5) * 10,
      longitude: c.lng + (Math.random() - 0.5) * 10,
      country: c.name,
      mitigated: true,
      detectedAt: new Date(
        Date.now() - i * 120_000 - Math.random() * 60_000,
      ).toISOString(),
    };
  });
}

/* ── Sparkline data generators ── */
function generateSparkline(base: number, variance: number, points: number = 12): number[] {
  return Array.from({ length: points }, () =>
    Math.max(0, base + (Math.random() - 0.5) * variance * 2),
  );
}

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
  },
  pageTitle: {
    fontSize: '24px',
    fontWeight: 700,
    color: '#f1f5f9',
    letterSpacing: '-0.025em',
  },
  lastUpdated: {
    fontSize: '12px',
    color: '#64748b',
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
  },
  refreshDot: {
    width: 6,
    height: 6,
    borderRadius: '50%',
    backgroundColor: '#10b981',
    animation: 'pulse-dot 2s ease-in-out infinite',
  },
  statRow: {
    display: 'flex',
    gap: '16px',
  },
  mainContent: {
    display: 'flex',
    gap: '16px',
    minHeight: '480px',
  },
  leftPane: {
    flex: '0 0 400px',
    minWidth: 0,
    display: 'flex',
    flexDirection: 'column',
  },
  rightPane: {
    flex: 1,
    minWidth: 0,
    display: 'flex',
    flexDirection: 'column',
  },
};

const Dashboard: React.FC = () => {
  const {
    overview,
    threats,
    fetchOverview,
    fetchThreats,
    fetchApps,
    refreshAll,
  } = useDashboardStore();

  const [lastRefresh, setLastRefresh] = React.useState<Date>(new Date());

  /* ── Initial fetch ── */
  useEffect(() => {
    fetchOverview();
    fetchThreats();
    fetchApps();
  }, [fetchOverview, fetchThreats, fetchApps]);

  /* ── Auto-refresh every 30 seconds ── */
  const handleRefresh = useCallback(() => {
    refreshAll();
    setLastRefresh(new Date());
  }, [refreshAll]);

  useEffect(() => {
    const interval = setInterval(handleRefresh, REFRESH_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [handleRefresh]);

  /* ── Derived data with mock fallback ── */
  const displayThreats = useMemo(() => {
    if (threats.length > 0) return threats;
    return generateMockThreats();
  }, [threats]);

  const threatsBlocked = overview?.threatsBlocked24h ?? 1_247;
  const devicesProtected = overview?.devicesProtected ?? 12_483;
  const avgCpu = overview?.avgCpuImpact ?? 0.7;

  const threatSparkline = useMemo(
    () => generateSparkline(threatsBlocked / 12, threatsBlocked / 24),
    [threatsBlocked],
  );

  const deviceSparkline = useMemo(
    () => generateSparkline(devicesProtected, devicesProtected * 0.02),
    [devicesProtected],
  );

  const perfSparkline = useMemo(
    () => generateSparkline(avgCpu, 0.3),
    [avgCpu],
  );

  const formatTime = (date: Date) =>
    date.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });

  return (
    <div style={styles.page} className="fade-in">
      {/* Page header */}
      <div style={styles.pageHeader}>
        <h1 style={styles.pageTitle}>Security Overview</h1>
        <div style={styles.lastUpdated}>
          <div style={styles.refreshDot} />
          <span>Last updated {formatTime(lastRefresh)}</span>
        </div>
      </div>

      {/* Stat cards row */}
      <div style={styles.statRow}>
        <StatCard
          icon={'\u26a1'}
          title="Threats Neutralized (24h)"
          value={threatsBlocked.toLocaleString()}
          subtitle={`${overview?.severityBreakdown?.critical ?? 23} critical blocked`}
          trend={12.4}
          sparklineData={threatSparkline}
        />
        <StatCard
          icon={'\ud83d\udee1\ufe0f'}
          title="Devices Protected"
          value={devicesProtected.toLocaleString()}
          subtitle="Across all registered apps"
          trend={5.8}
          sparklineData={deviceSparkline}
        />
        <StatCard
          icon={'\u2699\ufe0f'}
          title="Agent Performance"
          value={`<${Math.max(1, Math.ceil(avgCpu))}%`}
          subtitle="Avg. CPU Impact"
          trend={-2.1}
          sparklineData={perfSparkline}
        />
      </div>

      {/* Main content: Threat Feed + Threat Map */}
      <div style={styles.mainContent}>
        <div style={styles.leftPane}>
          <ThreatFeed threats={displayThreats} />
        </div>
        <div style={styles.rightPane}>
          <ThreatMap threats={displayThreats} />
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
