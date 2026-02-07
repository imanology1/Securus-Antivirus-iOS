import { Router } from 'express';
import * as reportController from '../controllers/report.controller';
import { apiKeyMiddleware } from '../../middleware/apikey.middleware';

const router = Router();

// POST /v1/report - Receive anonymized threat report from iOS SDK
// Authenticated via X-API-Key header (not JWT - this is the SDK endpoint)
router.post('/report', apiKeyMiddleware, reportController.submitReport);

export default router;
