import { NextFunction, Request, Response } from 'express';
import { AppError } from '../../errors/AppError';
import * as authService from './auth.service';

export async function registerHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const body = req.body ?? {};
    const result = await authService.register({
      fullName: typeof body.full_name === 'string' ? body.full_name : '',
      email: typeof body.email === 'string' ? body.email : '',
      phone: typeof body.phone === 'string' ? body.phone : null,
      password: typeof body.password === 'string' ? body.password : '',
    });
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function loginHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const body = req.body ?? {};
    const result = await authService.login({
      email: typeof body.email === 'string' ? body.email : '',
      password: typeof body.password === 'string' ? body.password : '',
    });
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function meHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    if (!req.user) {
      // Ne devrait jamais arriver derrière le middleware `authenticate`,
      // gardé par sécurité/lisibilité.
      throw new AppError(401, 'AUTH_TOKEN_MISSING', 'Authentification requise.');
    }
    const user = await authService.getCurrentUser(req.user.id);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
}
