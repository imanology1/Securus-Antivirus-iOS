import { Router } from 'express';
import authRoutes from './auth.routes';
import reportRoutes from './report.routes';
import threatsRoutes from './threats.routes';
import appsRoutes from './apps.routes';
import analyticsRoutes from './analytics.routes';
import healthRoutes from './health.routes';

const router = Router();

// Health check (no version prefix - always accessible)
router.use(healthRoutes);

// Auth routes (no version prefix for login/register)
router.use('/auth', authRoutes);

// API v1 routes
router.use('/v1', reportRoutes);
router.use('/v1', threatsRoutes);
router.use('/v1', appsRoutes);
router.use('/v1', analyticsRoutes);

export default router;
