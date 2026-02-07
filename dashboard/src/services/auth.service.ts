import apiClient from '@/config/api.config';
import type {
  LoginRequest,
  RegisterRequest,
  AuthResponse,
  Developer,
} from '@/types';

const TOKEN_KEY = 'securus_token';
const DEV_KEY = 'securus_developer';

export const authService = {
  async login(payload: LoginRequest): Promise<AuthResponse> {
    const { data } = await apiClient.post<AuthResponse>('/auth/login', payload);
    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(DEV_KEY, JSON.stringify(data.developer));
    return data;
  },

  async register(payload: RegisterRequest): Promise<AuthResponse> {
    const { data } = await apiClient.post<AuthResponse>('/auth/register', payload);
    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(DEV_KEY, JSON.stringify(data.developer));
    return data;
  },

  logout(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(DEV_KEY);
  },

  getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  },

  getCurrentDeveloper(): Developer | null {
    const raw = localStorage.getItem(DEV_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as Developer;
    } catch {
      return null;
    }
  },

  isAuthenticated(): boolean {
    return !!localStorage.getItem(TOKEN_KEY);
  },

  async fetchCurrentUser(): Promise<Developer> {
    const { data } = await apiClient.get<Developer>('/auth/me');
    localStorage.setItem(DEV_KEY, JSON.stringify(data));
    return data;
  },
};
