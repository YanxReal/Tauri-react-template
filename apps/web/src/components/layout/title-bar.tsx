import { useEffect } from "react"

import { useMacDragRegion, usePlatform } from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

/**
 * Titlebar side-effects only — Prestly pattern para macOS Overlay.
 * En Win/Linux el Header maneja los caption buttons alineados
 * horizontalmente, aquí solo se monta la clase .titlebar.
 */
export function TitleBar() {
  const platform = usePlatform()
  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"

  useMacDragRegion(visible && isMac)

  useEffect(() => {
    if (!visible) return
    document.documentElement.classList.add("titlebar")
    if (platform === "windows" || platform === "linux")
      document.documentElement.classList.add("titlebar-win")
    if (isMac) document.documentElement.classList.add("titlebar-mac")
    return () => {
      document.documentElement.classList.remove("titlebar")
      document.documentElement.classList.remove("titlebar-win")
      document.documentElement.classList.remove("titlebar-mac")
    }
  }, [visible, platform, isMac])

  return null
}
