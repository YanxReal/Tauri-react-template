import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vitest/config"

const host = process.env.TAURI_DEV_HOST

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": new URL("./src", import.meta.url).pathname,
    },
  },
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    // `tauri ios dev` negotiates devUrl on a network IP (the first
    // non-loopback local interface; on this machine it sometimes lands on the
    // PairVPN one) and probes the server there. Listening on ALL interfaces
    // (host: true) passes the CLI health-check on any IP (127.0.0.1, ::1 or
    // LAN). When the CLI exports TAURI_DEV_HOST (physical device) we pin that
    // exact host.
    host: host || true,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    css: true,
  },
})
