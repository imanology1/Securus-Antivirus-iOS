import { Request, Response, NextFunction } from 'express';
import * as threatService from '../../services/threat.service';
import { ThreatType, Severity } from '../../models';

export async function listThreats(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;

    // Parse pagination
    const page = Math.max(1, parseInt(req.query.page as string, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string, 10) || 20));
    const offset = (page - 1) * limit;

    // Parse filters
    const filters = {
      app_id: req.query.app_id as string | undefined,
      threat_type: req.query.threat_type as ThreatType | undefined,
      severity: req.query.severity as Severity | undefined,
      start_date: req.query.start_date as string | undefined,
      end_date: req.query.end_date as string | undefined,
    };

    const result = await threatService.listThreats(
      developer.id,
      filters,
      { page, limit, offset }
    );

    const totalPages = Math.ceil(result.total / limit);

    res.status(200).json({
      status: 'success',
      data: {
        threats: result.threats,
        pagination: {
          page,
          limit,
          total: result.total,
          total_pages: totalPages,
          has_next: page < totalPages,
          has_prev: page > 1,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function getStats(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;
    const appId = req.query.app_id as string | undefined;

    const stats = await threatService.getThreatStats(developer.id, appId);

    res.status(200).json({
      status: 'success',
      data: stats,
    });
  } catch (error) {
    next(error);
  }
}
