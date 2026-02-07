import { Request, Response, NextFunction } from 'express';
import { registerSchema, loginSchema } from '../validators/auth.validator';
import * as authService from '../../services/auth.service';

export async function register(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const validated = registerSchema.parse(req.body);

    const result = await authService.registerDeveloper(
      validated.email,
      validated.password,
      validated.company_name
    );

    res.status(201).json({
      status: 'success',
      data: {
        developer: result.developer,
        token: result.token,
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function login(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const validated = loginSchema.parse(req.body);

    const result = await authService.loginDeveloper(
      validated.email,
      validated.password
    );

    res.status(200).json({
      status: 'success',
      data: {
        developer: result.developer,
        token: result.token,
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function me(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const developer = req.developer!;

    const publicDev = await authService.getDeveloperById(developer.id);

    res.status(200).json({
      status: 'success',
      data: { developer: publicDev },
    });
  } catch (error) {
    next(error);
  }
}
