import { useEffect } from "react"

import {
  useMacDragRegion,
  usePlatform,
  useWindowResizeEdges,
} from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

/**
 * Titlebar side-effects only — side effects for the macOS Overlay titlebar.
 * Only the `.titlebar` class is mounted here (band height + shell styles).
 */
export function TitleBar() {
  const platform = usePlatform()
  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"
  const isLinux = platform === "linux"

  useMacDragRegion(visible && isMac)
  // Linux frameless no trae agarres de resize: los pone la app.
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
