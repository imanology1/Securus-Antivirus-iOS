import apiClient from '@/config/api.config';
import type {
  ThreatEvent,
  PaginatedResponse,
  PaginationParams,
  TimelineDataPoint,
  AnalyticsOverview,
} from '@/types';

export const threatService = {
  async getThreats(
    params: PaginationParams & { appId?: string; severity?: string }
  ): Promise<PaginatedResponse<ThreatEvent>> {
    const { data } = await apiClient.get<PaginatedResponse<ThreatEvent>>(
      '/threats',
      { params }
    );
    return data;
  },

  async getThreatStats(appId?: string): Promise<AnalyticsOverview> {
    const { data } = await apiClient.get<AnalyticsOverview>('/threats/stats', {
      params: appId ? { appId } : undefined,
    });
    return data;
  },

  async getTimeline(
    range: '24h' | '7d' | '30d' = '24h',
    appId?: string
  ): Promise<TimelineDataPoint[]> {
    const { data } = await apiClient.get<TimelineDataPoint[]>(
      '/threats/timeline',
      { params: { range, appId } }
    );
    return data;
  },
};
