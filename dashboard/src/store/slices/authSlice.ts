import { create } from 'zustand';
import type { Developer } from '@/types';
import { authService } from '@/services/auth.service';

interface AuthState {
  developer: Developer | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;

  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, companyName: string) => Promise<void>;
  logout: () => void;
  hydrate: () => void;
  clearError: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  developer: authService.getCurrentDeveloper(),
  token: authService.getToken(),
  isAuthenticated: authService.isAuthenticated(),
  isLoading: false,
  error: null,

  login: async (email, password) => {
    set({ isLoading: true, error: null });
    try {
      const res = await authService.login({ email, password });
      set({
        developer: res.developer,
        token: res.token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Login failed. Please try again.';
      set({ isLoading: false, error: message });
      throw err;
    }
  },

  register: async (email, password, companyName) => {
    set({ isLoading: true, error: null });
    try {
      const res = await authService.register({ email, password, companyName });
      set({
        developer: res.developer,
        token: res.token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Registration failed. Please try again.';
      set({ isLoading: false, error: message });
      throw err;
    }
  },

  logout: () => {
    authService.logout();
    set({
      developer: null,
      token: null,
      isAuthenticated: false,
      error: null,
    });
  },

  hydrate: () => {
    set({
      developer: authService.getCurrentDeveloper(),
      token: authService.getToken(),
      isAuthenticated: authService.isAuthenticated(),
    });
  },

  clearError: () => set({ error: null }),
}));
