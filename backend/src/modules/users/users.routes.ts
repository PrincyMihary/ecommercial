import { Router } from 'express';
import { authenticate } from '../../middleware/auth';
import { meHandler } from '../auth/auth.controller';

/**
 * Module `users` volontairement minimal à ce stade : seule la route
 * `/users/me` est demandée pour le module Auth. Les futurs modules
 * (shops, products, ...) pourront enrichir ce module ou le laisser tel
 * quel selon leurs besoins — non decidé ici, hors périmètre.
 */
const router = Router();

router.get('/me', authenticate, meHandler);

export default router;
