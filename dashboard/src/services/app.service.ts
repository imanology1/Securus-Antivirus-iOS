import apiClient from '@/config/api.config';
import type { App } from '@/types';

export const appService = {
  async getApps(): Promise<App[]> {
    const { data } = await apiClient.get<App[]>('/apps');
    return data;
  },

  async createApp(payload: {
    name: string;
    bundleId: string;
    platform: 'ios' | 'android' | 'cross-platform';
  }): Promise<App> {
    const { data } = await apiClient.post<App>('/apps', payload);
    return data;
  },

  async deleteApp(appId: string): Promise<void> {
    await apiClient.delete(`/apps/${appId}`);
  },

  async regenerateApiKey(appId: string): Promise<{ apiKey: string }> {
    const { data } = await apiClient.post<{ apiKey: string }>(
      `/apps/${appId}/regenerate-key`
    );
    return data;
  },
};
