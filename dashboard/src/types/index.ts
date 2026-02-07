/* ─────────────────────────────────────────────────────────────
   Securus Dashboard – Shared TypeScript Types
   ───────────────────────────────────────────────────────────── */

export enum ThreatType {
  MALWARE = 'malware',
  NETWORK_INTRUSION = 'network_intrusion',
  PHISHING = 'phishing',
  JAILBREAK = 'jailbreak',
  DATA_EXFILTRATION = 'data_exfiltration',
  MAN_IN_THE_MIDDLE = 'man_in_the_middle',
  CODE_INJECTION = 'code_injection',
  PRIVILEGE_ESCALATION = 'privilege_escalation',
  RANSOMWARE = 'ransomware',
  SPYWARE = 'spyware',
}

export enum Severity {
  CRITICAL = 'critical',
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low',
}

/* ── API entities ── */

export interface Developer {
  id: string;
  email: string;
  companyName: string;
  createdAt: string;
  plan: 'free' | 'pro' | 'enterprise';
  apiKey?: string;
}

export interface App {
  id: string;
  name: string;
  bundleId: string;
  platform: 'ios' | 'android' | 'cross-platform';
  apiKey: string;
  createdAt: string;
  devicesCount: number;
  isActive: boolean;
}

export interface ThreatEvent {
  id: string;
  appId: string;
  deviceId: string;
  threatType: ThreatType;
  severity: Severity;
  description: string;
  sourceIp?: string;
  latitude?: number;
  longitude?: number;
  country?: string;
  mitigated: boolean;
  detectedAt: string;
  resolvedAt?: string;
  metadata?: Record<string, unknown>;
}

export interface AnalyticsOverview {
  threatsBlocked24h: number;
  threatsBlocked7d: number;
  threatsBlocked30d: number;
  devicesProtected: number;
  avgCpuImpact: number;
  avgMemoryImpact: number;
  topThreatType: ThreatType;
  severityBreakdown: {
    critical: number;
    high: number;
    medium: number;
    low: number;
  };
}

export interface TimelineDataPoint {
  timestamp: string;
  count: number;
  label?: string;
}

export interface ThreatDistribution {
  threatType: ThreatType;
  count: number;
  percentage: number;
}

export interface TopThreatenedApp {
  appId: string;
  appName: string;
  threatCount: number;
  topThreatType: ThreatType;
}

/* ── Auth payloads ── */

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  companyName: string;
}

export interface AuthResponse {
  token: string;
  developer: Developer;
}

/* ── Pagination ── */

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface PaginationParams {
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/* ── API error ── */

export interface ApiError {
  message: string;
  statusCode: number;
  errors?: Record<string, string[]>;
}
