import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// In dev, proxy API calls to the StreamHub server so the browser talks to a
// single origin (no CORS, and HLS relative segment URLs resolve cleanly).
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:8080',
      '/healthz': 'http://localhost:8080',
    },
  },
})
