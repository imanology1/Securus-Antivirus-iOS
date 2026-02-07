import { Router } from 'express';
import * as appsController from '../controllers/apps.controller';
import { authMiddleware } from '../../middleware/auth.middleware';

const router = Router();

// All app routes require JWT authentication (dashboard access)
router.use(authMiddleware);

// POST /v1/apps - Create a new app and generate API key
router.post('/apps', appsController.createApp);

// GET /v1/apps - List all apps for the authenticated developer
router.get('/apps', appsController.listApps);

// GET /v1/apps/:id - Get a specific app
router.get('/apps/:id', appsController.getApp);

// DELETE /v1/apps/:id - Delete an app
router.delete('/apps/:id', appsController.deleteApp);

export default router;
