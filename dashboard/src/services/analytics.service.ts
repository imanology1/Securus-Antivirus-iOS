import apiClient from '@/config/api.config';
import type {
  AnalyticsOverview,
  TimelineDataPoint,
  ThreatDistribution,
  TopThreatenedApp,
} from '@/types';

export const analyticsService = {
  async getOverview(appId?: string): Promise<AnalyticsOverview> {
    const { data } = await apiClient.get<AnalyticsOverview>(
      '/analytics/overview',
      { params: appId ? { appId } : undefined }
    );
    return data;
  },

  async getTimeline(
    range: '24h' | '7d' | '30d' = '24h',
    appId?: string
  ): Promise<TimelineDataPoint[]> {
    const { data } = await apiClient.get<TimelineDataPoint[]>(
      '/analytics/timeline',
      { params: { range, appId } }
    );
    return data;
  },

  async getTopThreats(appId?: string): Promise<ThreatDistribution[]> {
    const { data } = await apiClient.get<ThreatDistribution[]>(
      '/analytics/top-threats',
      { params: appId ? { appId } : undefined }
    );
    return data;
  },

  async getTopThreatenedApps(): Promise<TopThreatenedApp[]> {
    const { data } = await apiClient.get<TopThreatenedApp[]>(
      '/analytics/top-apps'
    );
    return data;
  },
};
