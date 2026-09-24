import { useEffect } from "react"

import {
  useMacDragRegion,
  useNativeTheme,
  usePlatform,
  useWindowResizeEdges,
} from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

/**
 * Titlebar side-effects only — Prestly pattern para macOS Overlay.
 * Aquí solo se monta la clase `.titlebar` (alto de banda + estilos del shell) y,
 * en Linux, se sincroniza la variante de GTK (`useNativeTheme`): esa ventana usa
 * un marco CSD "latched" y la titlebar visible la dibuja la app.
 */
export function TitleBar() {
  const platform = usePlatform()
  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"
  const isLinux = platform === "linux"

  useMacDragRegion(visible && isMac)
  useNativeTheme(visible && isLinux)
  // Linux CSD no trae agarres de resize: los pone la app.
  useWindowResizeEdges(visible && isLinux)

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
