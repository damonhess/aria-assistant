import path from 'path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
    preserveSymlinks: false,
  },
  optimizeDeps: {
    exclude: ['lucide-react'],
    include: [
      'react-router-dom',
      'zustand',
      'framer-motion',
      '@tanstack/react-query',
      '@supabase/supabase-js',
      'react',
      'react-dom',
    ],
    force: true,
  },
  server: {
    fs: {
      strict: false,
      allow: ['/tmp', '/home'],
    },
  },
});
