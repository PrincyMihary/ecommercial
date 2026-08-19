import { Router } from 'express';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import { login, me, register } from './auth.controller';

export const authRouter = Router();
authRouter.post('/register', asyncHandler(register));
authRouter.post('/login', asyncHandler(login));

// GET /users/me est monté séparément dans app.ts (préfixe /users), mais
// partage ce même contrôleur.
export const usersRouter = Router();
usersRouter.get('/me', requireAuth, asyncHandler(me));
