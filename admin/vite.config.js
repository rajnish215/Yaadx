import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  test: { environment: "jsdom" },
  server: {
    port: 5174,
    strictPort: true,
    proxy: { "/v1": "http://127.0.0.1:8080" },
  },
  preview: {
    port: 5174,
    strictPort: true,
    proxy: { "/v1": "http://127.0.0.1:8080" },
  },
});
