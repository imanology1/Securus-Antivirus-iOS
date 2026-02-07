import pool from '../config/database';
import { AnalyticsOverview, TimelineDataPoint } from '../models';

export async function getOverview(
  developerId: string
): Promise<AnalyticsOverview> {
  // Threats blocked in last 24 hours
  const threats24hResult = await pool.query(
    `SELECT COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $1
       AND te.created_at >= NOW() - INTERVAL '24 hours'`,
    [developerId]
  );

  // Distinct devices (app_tokens) protected
  const devicesResult = await pool.query(
    `SELECT COUNT(DISTINCT te.app_token) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $1`,
    [developerId]
  );

  // Top threat types (last 30 days)
  const topThreatsResult = await pool.query(
    `SELECT te.threat_type, COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $1
       AND te.created_at >= NOW() - INTERVAL '30 days'
     GROUP BY te.threat_type
     ORDER BY count DESC
     LIMIT 10`,
    [developerId]
  );

  // Severity distribution (last 30 days)
  const severityResult = await pool.query(
    `SELECT te.severity, COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $1
       AND te.created_at >= NOW() - INTERVAL '30 days'
     GROUP BY te.severity
     ORDER BY count DESC`,
    [developerId]
  );

  return {
    threats_blocked_24h: parseInt(threats24hResult.rows[0].count, 10),
    devices_protected: parseInt(devicesResult.rows[0].count, 10),
    top_threat_types: topThreatsResult.rows.map((row) => ({
      threat_type: row.threat_type,
      count: parseInt(row.count, 10),
    })),
    severity_distribution: severityResult.rows.map((row) => ({
      severity: row.severity,
      count: parseInt(row.count, 10),
    })),
  };
}

export async function getTimeline(
  developerId: string,
  interval: string = '1 hour',
  days: number = 7
): Promise<TimelineDataPoint[]> {
  // Validate interval to prevent SQL injection
  const allowedIntervals: Record<string, string> = {
    '15 minutes': '15 minutes',
    '30 minutes': '30 minutes',
    '1 hour': '1 hour',
    '6 hours': '6 hours',
    '1 day': '1 day',
    '1 week': '1 week',
  };

  const safeInterval = allowedIntervals[interval] || '1 hour';

  // Validate days range
  const safeDays = Math.min(Math.max(days, 1), 365);

  const result = await pool.query(
    `SELECT
       time_bucket($1::interval, te.created_at) AS bucket,
       COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $2
       AND te.created_at >= NOW() - ($3 || ' days')::interval
     GROUP BY bucket
     ORDER BY bucket ASC`,
    [safeInterval, developerId, safeDays.toString()]
  );

  return result.rows.map((row) => ({
    bucket: row.bucket,
    count: parseInt(row.count, 10),
  }));
}

export async function getTimelineByThreatType(
  developerId: string,
  interval: string = '1 hour',
  days: number = 7
): Promise<TimelineDataPoint[]> {
  const allowedIntervals: Record<string, string> = {
    '15 minutes': '15 minutes',
    '30 minutes': '30 minutes',
    '1 hour': '1 hour',
    '6 hours': '6 hours',
    '1 day': '1 day',
    '1 week': '1 week',
  };

  const safeInterval = allowedIntervals[interval] || '1 hour';
  const safeDays = Math.min(Math.max(days, 1), 365);

  const result = await pool.query(
    `SELECT
       time_bucket($1::interval, te.created_at) AS bucket,
       te.threat_type,
       COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     WHERE a.developer_id = $2
       AND te.created_at >= NOW() - ($3 || ' days')::interval
     GROUP BY bucket, te.threat_type
     ORDER BY bucket ASC, count DESC`,
    [safeInterval, developerId, safeDays.toString()]
  );

  return result.rows.map((row) => ({
    bucket: row.bucket,
    threat_type: row.threat_type,
    count: parseInt(row.count, 10),
  }));
}
