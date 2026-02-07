import { Router } from 'express';
import * as authController from '../controllers/auth.controller';
import { authMiddleware } from '../../middleware/auth.middleware';

const router = Router();

// POST /auth/register - Create a new developer account
router.post('/register', authController.register);

// POST /auth/login - Authenticate and receive JWT
router.post('/login', authController.login);

// GET /auth/me - Get current authenticated developer
router.get('/me', authMiddleware, authController.me);

export default router;
