import React from 'react';
import { Routes, Route, Navigate, Outlet } from 'react-router-dom';
import './styles/globals.css';
import './styles/themes/dark.css';
import Layout from '@/components/Layout/Layout';
import ProtectedRoute from '@/routes/ProtectedRoute';
import Login from '@/pages/Auth/Login';
import Register from '@/pages/Auth/Register';
import Dashboard from '@/pages/Dashboard/Dashboard';
import Analytics from '@/pages/Analytics/Analytics';
import Configuration from '@/pages/Configuration/Configuration';

const App: React.FC = () => {
  return (
    <Routes>
      {/* Public routes */}
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />

      {/* Protected routes with Layout */}
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <Layout>
              <Outlet />
            </Layout>
          </ProtectedRoute>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="analytics" element={<Analytics />} />
        <Route path="configuration" element={<Configuration />} />
      </Route>

      {/* Catch-all redirect */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default App;
