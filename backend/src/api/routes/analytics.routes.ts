import { Router } from 'express';
import * as analyticsController from '../controllers/analytics.controller';
import { authMiddleware } from '../../middleware/auth.middleware';

const router = Router();

// All analytics routes require JWT authentication (dashboard access)
router.use(authMiddleware);

// GET /v1/analytics/overview - Dashboard summary: threats 24h, devices, top types
router.get('/analytics/overview', analyticsController.getOverview);

// GET /v1/analytics/timeline - Time-series data for charts
// Query params: interval (e.g. "1 hour"), days (e.g. 7), group_by_type (true/false)
router.get('/analytics/timeline', analyticsController.getTimeline);

export default router;
