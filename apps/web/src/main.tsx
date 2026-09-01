import { openUrl } from "@tauri-apps/plugin-opener"
import { StrictMode } from "react"
import { createRoot } from "react-dom/client"

import "@workspace/ui/globals.css"
import "./i18n/config.ts"
import { GlassCardsProvider } from "@/components/glass-cards-provider.tsx"
import { ThemeProvider } from "@/components/theme-provider.tsx"
import { VibrancyProvider } from "@/components/vibrancy-provider.tsx"
import { App } from "./App.tsx"

// --- Native-app feel (multi-OS) ---------------------------------------------
// Bloquear atajos "de navegador" (F5, Cmd+R, DevTools, Ctrl+P/S, zoom por
// teclado, menú contextual) lo hace el plugin Rust `tauri-plugin-prevent-default`
// de forma PERFIL-condicional (en debug conserva DevTools y el menú Recargar),
// así que aquí solo cubrimos lo que no gestiona el plugin:
//   - arrastre de elementos (dragstart)
//   - zoom con Ctrl/Cmd + rueda del ratón (fallback escritorio)
//   - enlaces externos → navegador del OS, nunca dentro del webview
// ----------------------------------------------------------------------------
const isTauri = "__TAURI_INTERNALS__" in window

document.addEventListener("dragstart", e => e.preventDefault())
document.addEventListener(
  "wheel",
  e => {
    if (e.ctrlKey || e.metaKey) e.preventDefault()
  },
  { passive: false }
)

if (isTauri) {
  document.addEventListener(
    "click",
    e => {
      const target = e.target as Element | null
      const anchor = target?.closest?.("a")
      const href = anchor?.getAttribute("href")
      if (anchor && href && /^(https?:|mailto:|tel:)/i.test(href)) {
        e.preventDefault()
        void openUrl(href).catch(() => {})
      }
    },
    true
  )
}

const root = document.getElementById("root")
if (!root) throw new Error("Root element not found")

createRoot(root).render(
  <StrictMode>
    <ThemeProvider>
      <VibrancyProvider>
        <GlassCardsProvider>
          <App />
        </GlassCardsProvider>
      </VibrancyProvider>
    </ThemeProvider>
  </StrictMode>
)
