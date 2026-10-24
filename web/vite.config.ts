import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  server: {
    port: 5173,
    strictPort: true,
    watch: { usePolling: process.env.VITE_USE_POLLING === 'true', interval: 500 },
    proxy: {
      '/api/monitor/': {
        target: process.env.PLATFORM_API_TARGET ?? 'http://host.docker.internal:52779',
        changeOrigin: true,
      },
    },
  },
  preview: { port: 5173, strictPort: true },
})
