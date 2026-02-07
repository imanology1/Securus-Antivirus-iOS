import { Request, Response, NextFunction } from 'express';
import * as analyticsService from '../../services/analytics.service';

export async function getOverview(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;

    const overview = await analyticsService.getOverview(developer.id);

    res.status(200).json({
      status: 'success',
      data: overview,
    });
  } catch (error) {
    next(error);
  }
}

export async function getTimeline(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;

    const interval = (req.query.interval as string) || '1 hour';
    const days = parseInt(req.query.days as string, 10) || 7;
    const groupByType = req.query.group_by_type === 'true';

    let timeline;

    if (groupByType) {
      timeline = await analyticsService.getTimelineByThreatType(
        developer.id,
        interval,
        days
      );
    } else {
      timeline = await analyticsService.getTimeline(
        developer.id,
        interval,
        days
      );
    }

    res.status(200).json({
      status: 'success',
      data: {
        timeline,
        params: {
          interval,
          days,
          group_by_type: groupByType,
        },
      },
    });
  } catch (error) {
    next(error);
  }
}
