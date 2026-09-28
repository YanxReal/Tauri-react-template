import { openUrl } from "@tauri-apps/plugin-opener"
import { StrictMode } from "react"
import { createRoot } from "react-dom/client"

import "@workspace/ui/globals.css"
import "./i18n/config.ts"
import { AppProviders } from "@/components/app-providers.tsx"
import { App } from "./App.tsx"

// --- Native-app feel (multi-OS) ---------------------------------------------
// Blocking "browser" shortcuts (F5, Cmd+R, DevTools, Ctrl+P/S, keyboard
// zoom, context menu) is the Rust `tauri-plugin-prevent-default` plugin's job,
// applied per profile (debug keeps DevTools and the Reload menu), so here we
// only cover what the plugin does not handle:
//   - element dragging (dragstart)
//   - Ctrl/Cmd + wheel zoom (desktop fallback)
//   - external links → OS browser, never inside the webview
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
    <AppProviders>
      <App />
    </AppProviders>
  </StrictMode>
)
