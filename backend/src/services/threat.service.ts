import pool from '../config/database';
import {
  ThreatEvent,
  ThreatReportPayload,
  ThreatFilter,
  ThreatStats,
  PaginationParams,
} from '../models';
import { logger } from '../utils/logger';

export async function createThreatEvent(
  appId: string,
  payload: ThreatReportPayload
): Promise<ThreatEvent> {
  const result = await pool.query(
    `INSERT INTO threat_events (threat_id, app_id, threat_type, severity, metadata, app_token, sdk_version, os_version)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      payload.threat_id,
      appId,
      payload.threat_type,
      payload.severity,
      JSON.stringify(payload.metadata),
      payload.app_token,
      payload.sdk_version,
      payload.os_version,
    ]
  );

  logger.debug(`Threat event created: ${payload.threat_id} for app ${appId}`);
  return result.rows[0] as ThreatEvent;
}

export async function listThreats(
  developerId: string,
  filters: ThreatFilter,
  pagination: PaginationParams
): Promise<{ threats: ThreatEvent[]; total: number }> {
  const conditions: string[] = ['a.developer_id = $1'];
  const params: unknown[] = [developerId];
  let paramIndex = 2;

  if (filters.app_id) {
    conditions.push(`te.app_id = $${paramIndex}`);
    params.push(filters.app_id);
    paramIndex++;
  }

  if (filters.threat_type) {
    conditions.push(`te.threat_type = $${paramIndex}`);
    params.push(filters.threat_type);
    paramIndex++;
  }

  if (filters.severity) {
    conditions.push(`te.severity = $${paramIndex}`);
    params.push(filters.severity);
    paramIndex++;
  }

  if (filters.start_date) {
    conditions.push(`te.created_at >= $${paramIndex}`);
    params.push(filters.start_date);
    paramIndex++;
  }

  if (filters.end_date) {
    conditions.push(`te.created_at <= $${paramIndex}`);
    params.push(filters.end_date);
    paramIndex++;
  }

  const whereClause = conditions.length > 0
    ? `WHERE ${conditions.join(' AND ')}`
    : '';

  // Get total count
  const countResult = await pool.query(
    `SELECT COUNT(*) as total
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     ${whereClause}`,
    params
  );

  const total = parseInt(countResult.rows[0].total, 10);

  // Get paginated results
  const dataParams = [...params, pagination.limit, pagination.offset];
  const dataResult = await pool.query(
    `SELECT te.*
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     ${whereClause}
     ORDER BY te.created_at DESC
     LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    dataParams
  );

  return {
    threats: dataResult.rows as ThreatEvent[],
    total,
  };
}

export async function getThreatStats(
  developerId: string,
  appId?: string
): Promise<ThreatStats> {
  const conditions: string[] = ['a.developer_id = $1'];
  const params: unknown[] = [developerId];
  let paramIndex = 2;

  if (appId) {
    conditions.push(`te.app_id = $${paramIndex}`);
    params.push(appId);
    paramIndex++;
  }

  // Suppress unused variable warning -- paramIndex reserved for future filters
  void paramIndex;

  const whereClause = `WHERE ${conditions.join(' AND ')}`;

  // Total count
  const totalResult = await pool.query(
    `SELECT COUNT(*) as total
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     ${whereClause}`,
    params
  );

  // By type
  const byTypeResult = await pool.query(
    `SELECT te.threat_type, COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     ${whereClause}
     GROUP BY te.threat_type
     ORDER BY count DESC`,
    params
  );

  // By severity
  const bySeverityResult = await pool.query(
    `SELECT te.severity, COUNT(*) as count
     FROM threat_events te
     JOIN apps a ON te.app_id = a.id
     ${whereClause}
     GROUP BY te.severity
     ORDER BY count DESC`,
    params
  );

  const byType: Record<string, number> = {};
  for (const row of byTypeResult.rows) {
    byType[row.threat_type] = parseInt(row.count, 10);
  }

  const bySeverity: Record<string, number> = {};
  for (const row of bySeverityResult.rows) {
    bySeverity[row.severity] = parseInt(row.count, 10);
  }

  return {
    total_threats: parseInt(totalResult.rows[0].total, 10),
    by_type: byType,
    by_severity: bySeverity,
  };
}
