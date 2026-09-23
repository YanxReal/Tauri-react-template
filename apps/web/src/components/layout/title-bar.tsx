import { useEffect } from "react"

import { useMacDragRegion, useNativeTheme, usePlatform } from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

/**
 * Titlebar side-effects only — Prestly pattern para macOS Overlay.
 * En Win/Linux la titlebar es nativa, así que aquí solo se monta la clase
 * `.titlebar` (alto de banda + estilos del shell). Linux es la excepción: su
 * barra es un `GtkHeaderBar` (CSD) que instala Rust, y `useNativeTheme` le
 * pasa el tema de la app para que la barra no se quede en el del sistema.
 */
export function TitleBar() {
  const platform = usePlatform()
  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"
  const isLinux = platform === "linux"

  useMacDragRegion(visible && isMac)
  useNativeTheme(visible && isLinux)

  useEffect(() => {
    if (!visible || !platform) return
    document.documentElement.classList.add("titlebar", platform)
    if (platform === "windows" || platform === "linux")
      document.documentElement.classList.add("titlebar-win")
    if (isMac) document.documentElement.classList.add("titlebar-mac")
    if (platform === "linux") document.documentElement.classList.add("linux")
    return () => {
      document.documentElement.classList.remove("titlebar", platform)
      document.documentElement.classList.remove("titlebar-win")
      document.documentElement.classList.remove("titlebar-mac")
      document.documentElement.classList.remove("linux")
    }
  }, [visible, platform, isMac])

  return null
}
