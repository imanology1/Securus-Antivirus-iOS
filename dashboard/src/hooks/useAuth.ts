import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/slices/authSlice';

/**
 * Custom hook that exposes auth state and actions.
 * Optionally redirects unauthenticated users to /login.
 */
export function useAuth(options?: { requireAuth?: boolean }) {
  const {
    developer,
    token,
    isAuthenticated,
    isLoading,
    error,
    login,
    register,
    logout,
    clearError,
  } = useAuthStore();

  const navigate = useNavigate();

  useEffect(() => {
    if (options?.requireAuth && !isAuthenticated) {
      navigate('/login', { replace: true });
    }
  }, [isAuthenticated, options?.requireAuth, navigate]);

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  return {
    developer,
    token,
    isAuthenticated,
    isLoading,
    error,
    login,
    register,
    logout: handleLogout,
    clearError,
  };
}
