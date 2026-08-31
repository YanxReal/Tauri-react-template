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
    // `tauri ios dev` negocia el devUrl con una IP de red (el primer
    // interfaz local no-loopback; en esta máquina a veces cae en la de
    // PairVPN) y comprueba el server en esa dirección. Escuchando en TODAS
    // las interfaces (host: true, como Prestly) la health-check del CLI
    // pasa en cualquier IP (127.0.0.1, ::1 o la de red). Cuando el CLI
    // exporta TAURI_DEV_HOST (device físico) vitamos ese host concreto.
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
