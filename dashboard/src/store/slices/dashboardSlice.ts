import { create } from 'zustand';
import type {
  AnalyticsOverview,
  ThreatEvent,
  TimelineDataPoint,
  ThreatDistribution,
  App,
} from '@/types';
import { ThreatType, Severity } from '@/types';
import { threatService } from '@/services/threat.service';
import { analyticsService } from '@/services/analytics.service';
import { appService } from '@/services/app.service';

/* ─────────────────────────────────────────
   Mock data used when the API is unreachable
   ───────────────────────────────────────── */

const mockOverview: AnalyticsOverview = {
  threatsBlocked24h: 1_247,
  threatsBlocked7d: 8_932,
  threatsBlocked30d: 34_561,
  devicesProtected: 12_483,
  avgCpuImpact: 0.7,
  avgMemoryImpact: 2.1,
  topThreatType: ThreatType.NETWORK_INTRUSION,
  severityBreakdown: { critical: 23, high: 187, medium: 542, low: 495 },
};

function randomThreat(index: number): ThreatEvent {
  const types = Object.values(ThreatType);
  const severities = Object.values(Severity);
  const countries = [
    { name: 'United States', lat: 38, lng: -97 },
    { name: 'Germany', lat: 51, lng: 10 },
    { name: 'China', lat: 35, lng: 105 },
    { name: 'Brazil', lat: -14, lng: -51 },
    { name: 'India', lat: 20, lng: 78 },
    { name: 'Russia', lat: 61, lng: 105 },
    { name: 'Japan', lat: 36, lng: 138 },
    { name: 'Nigeria', lat: 10, lng: 8 },
    { name: 'Australia', lat: -25, lng: 134 },
    { name: 'United Kingdom', lat: 55, lng: -3 },
    { name: 'France', lat: 46, lng: 2 },
    { name: 'South Korea', lat: 36, lng: 128 },
    { name: 'Iran', lat: 32, lng: 53 },
    { name: 'Mexico', lat: 23, lng: -102 },
    { name: 'Indonesia', lat: -5, lng: 120 },
  ];
  const c = countries[index % countries.length];
  const threatType = types[index % types.length];
  const severity = severities[index % severities.length];

  const descriptions: Record<string, string> = {
    [ThreatType.MALWARE]: 'Trojan payload detected in downloaded package',
    [ThreatType.NETWORK_INTRUSION]: 'Unauthorized network scan from external IP',
    [ThreatType.PHISHING]: 'Credential harvesting page blocked',
    [ThreatType.JAILBREAK]: 'Jailbreak detection bypass attempt',
    [ThreatType.DATA_EXFILTRATION]: 'Sensitive data upload to unknown endpoint',
    [ThreatType.MAN_IN_THE_MIDDLE]: 'SSL certificate pinning violation detected',
    [ThreatType.CODE_INJECTION]: 'Runtime code injection attempt blocked',
    [ThreatType.PRIVILEGE_ESCALATION]: 'Unauthorized privilege escalation attempt',
    [ThreatType.RANSOMWARE]: 'File encryption behavior detected and stopped',
    [ThreatType.SPYWARE]: 'Keylogger activity detected on device',
  };

  return {
    id: `mock-${index}-${Date.now()}`,
    appId: 'app-001',
    deviceId: `device-${(index * 37) % 999}`,
    threatType,
    severity,
    description: descriptions[threatType] || 'Threat detected',
    sourceIp: `${(index * 17) % 256}.${(index * 31) % 256}.${(index * 7) % 256}.${(index * 13) % 256}`,
    latitude: c.lat + (Math.random() - 0.5) * 10,
    longitude: c.lng + (Math.random() - 0.5) * 10,
    country: c.name,
    mitigated: true,
    detectedAt: new Date(
      Date.now() - index * 120_000 - Math.random() * 60_000
    ).toISOString(),
  };
}

const mockThreats: ThreatEvent[] = Array.from({ length: 50 }, (_, i) =>
  randomThreat(i)
);

function mockTimeline(range: '24h' | '7d' | '30d'): TimelineDataPoint[] {
  const points = range === '24h' ? 24 : range === '7d' ? 7 : 30;
  const now = Date.now();
  const interval =
    range === '24h'
      ? 3_600_000
      : range === '7d'
        ? 86_400_000
        : 86_400_000;
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

/* ─────────────────────────────────────────
   Dashboard Zustand store
   ───────────────────────────────────────── */

interface DashboardState {
  overview: AnalyticsOverview | null;
  threats: ThreatEvent[];
  timeline: TimelineDataPoint[];
  distribution: ThreatDistribution[];
  apps: App[];
  selectedAppId: string | null;
  timeRange: '24h' | '7d' | '30d';

  isLoadingOverview: boolean;
  isLoadingThreats: boolean;
  isLoadingTimeline: boolean;
  isLoadingDistribution: boolean;
  isLoadingApps: boolean;

  setTimeRange: (range: '24h' | '7d' | '30d') => void;
  setSelectedApp: (appId: string | null) => void;

  fetchOverview: () => Promise<void>;
  fetchThreats: () => Promise<void>;
  fetchTimeline: () => Promise<void>;
  fetchDistribution: () => Promise<void>;
  fetchApps: () => Promise<void>;
  refreshAll: () => Promise<void>;
}

export const useDashboardStore = create<DashboardState>((set, get) => ({
  overview: null,
  threats: [],
  timeline: [],
  distribution: [],
  apps: [],
  selectedAppId: null,
  timeRange: '24h',

  isLoadingOverview: false,
  isLoadingThreats: false,
  isLoadingTimeline: false,
  isLoadingDistribution: false,
  isLoadingApps: false,

  setTimeRange: (range) => {
    set({ timeRange: range });
    get().fetchTimeline();
  },

  setSelectedApp: (appId) => {
    set({ selectedAppId: appId });
    get().refreshAll();
  },

  fetchOverview: async () => {
    set({ isLoadingOverview: true });
    try {
      const data = await threatService.getThreatStats(
        get().selectedAppId ?? undefined
      );
      set({ overview: data, isLoadingOverview: false });
    } catch {
      set({ overview: mockOverview, isLoadingOverview: false });
    }
  },

  fetchThreats: async () => {
    set({ isLoadingThreats: true });
    try {
      const res = await threatService.getThreats({
        page: 1,
        pageSize: 50,
        appId: get().selectedAppId ?? undefined,
        sortBy: 'detectedAt',
        sortOrder: 'desc',
      });
      set({ threats: res.data, isLoadingThreats: false });
    } catch {
      set({ threats: mockThreats, isLoadingThreats: false });
    }
  },

  fetchTimeline: async () => {
    set({ isLoadingTimeline: true });
    try {
      const data = await analyticsService.getTimeline(
        get().timeRange,
        get().selectedAppId ?? undefined
      );
      set({ timeline: data, isLoadingTimeline: false });
    } catch {
      set({
        timeline: mockTimeline(get().timeRange),
        isLoadingTimeline: false,
      });
    }
  },

  fetchDistribution: async () => {
    set({ isLoadingDistribution: true });
    try {
      const data = await analyticsService.getTopThreats(
        get().selectedAppId ?? undefined
      );
      set({ distribution: data, isLoadingDistribution: false });
    } catch {
      set({ distribution: mockDistribution, isLoadingDistribution: false });
    }
  },

  fetchApps: async () => {
    set({ isLoadingApps: true });
    try {
      const data = await appService.getApps();
      set({ apps: data, isLoadingApps: false });
    } catch {
      set({ apps: mockApps, isLoadingApps: false });
    }
  },

  refreshAll: async () => {
    const s = get();
    await Promise.all([
      s.fetchOverview(),
      s.fetchThreats(),
      s.fetchTimeline(),
      s.fetchDistribution(),
    ]);
  },
}));
