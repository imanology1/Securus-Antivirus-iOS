import { Request, Response, NextFunction } from 'express';
import { validateThreatReport } from '../validators/report.validator';
import * as threatService from '../../services/threat.service';
import { logger } from '../../utils/logger';

export async function submitReport(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const app = req.app!;

    // Validate payload schema and check for PII
    const validated = validateThreatReport(req.body);

    // Insert the threat event
    const threatEvent = await threatService.createThreatEvent(app.id, {
      threat_id: validated.threat_id,
      threat_type: validated.threat_type,
      severity: validated.severity,
      metadata: validated.metadata,
      app_token: validated.app_token,
      sdk_version: validated.sdk_version,
      os_version: validated.os_version,
    });

    logger.info(
      `Threat report received: ${validated.threat_type} (${validated.severity}) from app ${app.name}`
    );

    res.status(201).json({
      status: 'success',
      data: {
        threat_id: threatEvent.threat_id,
        received_at: threatEvent.created_at,
      },
    });
  } catch (error) {
    next(error);
  }
}
