import { useEffect } from "react"

import {
  useMacDragRegion,
  usePlatform,
  useWindowResizeEdges,
} from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])
const KNOWN_PLATFORMS = new Set([...DESKTOP_PLATFORMS, "ios", "android", "web"])

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
    if (!platform || !KNOWN_PLATFORMS.has(platform)) return
    const root = document.documentElement
    // EVERY platform gets its class (html.ios / html.android drive the
    // mobile safe-area height in globals.css; html.linux/html.windows gate
    // desktop CSS). Only the titlebar* classes are desktop-only.
    root.classList.add(platform)
    if (!DESKTOP_PLATFORMS.has(platform)) {
      return () => root.classList.remove(platform)
    }
    root.classList.add("titlebar")
    if (platform === "windows" || platform === "linux")
      root.classList.add("titlebar-win")
    if (platform === "macos") root.classList.add("titlebar-mac")
    return () => {
      root.classList.remove(
        platform,
        "titlebar",
        "titlebar-win",
        "titlebar-mac"
      )
    }
  }, [platform])

  return null
}
