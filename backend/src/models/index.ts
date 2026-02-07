// ─── Enums ───────────────────────────────────────────────────────────────────

export enum ThreatType {
  Malware = 'malware',
  Phishing = 'phishing',
  NetworkThreat = 'network_threat',
  Jailbreak = 'jailbreak',
  Tampering = 'tampering',
  ManInTheMiddle = 'man_in_the_middle',
  SuspiciousProcess = 'suspicious_process',
  DataExfiltration = 'data_exfiltration',
  UnauthorizedAccess = 'unauthorized_access',
  Unknown = 'unknown',
}

export enum Severity {
  Critical = 'critical',
  High = 'high',
  Medium = 'medium',
  Low = 'low',
  Info = 'info',
}

export enum AppStatus {
  Active = 'active',
  Inactive = 'inactive',
  Suspended = 'suspended',
}

export enum SubscriptionPlan {
  Free = 'free',
  Pro = 'pro',
  Enterprise = 'enterprise',
}

export enum SubscriptionStatus {
  Active = 'active',
  Cancelled = 'cancelled',
  Expired = 'expired',
  Trial = 'trial',
}

// ─── Interfaces ──────────────────────────────────────────────────────────────

export interface Developer {
  id: string;
  email: string;
  password_hash: string;
  company_name: string;
  created_at: Date;
  updated_at: Date;
}

export interface DeveloperPublic {
  id: string;
  email: string;
  company_name: string;
  created_at: Date;
  updated_at: Date;
}

export interface App {
  id: string;
  developer_id: string;
  name: string;
  api_key: string;
  platform: string;
  created_at: Date;
  status: AppStatus;
}

export interface ThreatEvent {
  threat_id: string;
  app_id: string;
  threat_type: ThreatType;
  severity: Severity;
  metadata: Record<string, unknown>;
  app_token: string;
  sdk_version: string;
  os_version: string;
  created_at: Date;
}

export interface Subscription {
  id: string;
  developer_id: string;
  plan: SubscriptionPlan;
  status: SubscriptionStatus;
  events_limit: number;
  starts_at: Date;
  ends_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

// ─── Request/Response Types ──────────────────────────────────────────────────

export interface ThreatReportPayload {
  threat_id: string;
  threat_type: ThreatType;
  severity: Severity;
  metadata: Record<string, unknown>;
  app_token: string;
  sdk_version: string;
  os_version: string;
}

export interface PaginationParams {
  page: number;
  limit: number;
  offset: number;
}

export interface ThreatFilter {
  app_id?: string;
  threat_type?: ThreatType;
  severity?: Severity;
  start_date?: string;
  end_date?: string;
}

export interface ThreatStats {
  total_threats: number;
  by_type: Record<string, number>;
  by_severity: Record<string, number>;
}

export interface AnalyticsOverview {
  threats_blocked_24h: number;
  devices_protected: number;
  top_threat_types: Array<{ threat_type: string; count: number }>;
  severity_distribution: Array<{ severity: string; count: number }>;
}

export interface TimelineDataPoint {
  bucket: Date;
  count: number;
  threat_type?: string;
}
