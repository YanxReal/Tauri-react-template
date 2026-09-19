import { useEffect } from "react"

import { useMacDragRegion, usePlatform } from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

/**
 * Titlebar side-effects only — Prestly pattern para macOS Overlay.
 * En Win/Linux la titlebar es nativa (`decorations:true`), así que aquí solo
 * se monta la clase `.titlebar` (alto de banda + estilos del shell).
 */
export function TitleBar() {
  const platform = usePlatform()
  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"

  useMacDragRegion(visible && isMac)

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
