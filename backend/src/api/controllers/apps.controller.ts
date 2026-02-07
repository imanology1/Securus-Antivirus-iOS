import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import * as appService from '../../services/app.service';

const createAppSchema = z.object({
  name: z
    .string()
    .min(1, 'App name is required')
    .max(255, 'App name must be 255 characters or fewer')
    .trim(),
  platform: z
    .string()
    .default('ios')
    .refine(
      (val) => ['ios', 'android', 'cross-platform'].includes(val),
      'Platform must be ios, android, or cross-platform'
    ),
});

export async function createApp(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;
    const validated = createAppSchema.parse(req.body);

    const app = await appService.createApp(
      developer.id,
      validated.name,
      validated.platform
    );

    res.status(201).json({
      status: 'success',
      data: { app },
    });
  } catch (error) {
    next(error);
  }
}

export async function listApps(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;

    const apps = await appService.listApps(developer.id);

    res.status(200).json({
      status: 'success',
      data: { apps },
    });
  } catch (error) {
    next(error);
  }
}

export async function getApp(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;
    const { id } = req.params;

    const app = await appService.getAppById(developer.id, id);

    res.status(200).json({
      status: 'success',
      data: { app },
    });
  } catch (error) {
    next(error);
  }
}

export async function deleteApp(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;
    const { id } = req.params;

    await appService.deleteApp(developer.id, id);

    res.status(200).json({
      status: 'success',
      message: 'App deleted successfully',
    });
  } catch (error) {
    next(error);
  }
}
