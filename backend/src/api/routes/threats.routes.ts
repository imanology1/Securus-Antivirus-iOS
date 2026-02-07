import { Router } from 'express';
import * as threatsController from '../controllers/threats.controller';
import { authMiddleware } from '../../middleware/auth.middleware';

const router = Router();

// All threat routes require JWT authentication (dashboard access)
router.use(authMiddleware);

// GET /v1/threats - List threats with pagination and filters
router.get('/threats', threatsController.listThreats);

// GET /v1/threats/stats - Aggregated threat statistics
router.get('/threats/stats', threatsController.getStats);

export default router;
