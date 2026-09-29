import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { useEffect, useState } from "react"

/**
 * Drag-band height. Measured from the header itself (`.app-header`) instead
 * of duplicating its Tailwind class: if the band changes (52px macOS, 44px
 * Win/Linux, 56px mobile) dragging follows without touching two places.
 * Fallbacks apply when the header is not mounted yet.
 */
const FALLBACK_BAND_MAC = 52
const FALLBACK_BAND_DESKTOP = 44

function headerBandHeight(fallback: number): number {
  const header = document.querySelector(".app-header")
  const height = header?.getBoundingClientRect().height
  return height && height > 0 ? height : fallback
}

/** Targets that keep their click even inside the drag region. */
const INTERACTIVE_SELECTOR =
  "button, a, input, select, textarea, label, [role='button'], [data-no-drag]"

function isTauriRuntime() {
  return "__TAURI_INTERNALS__" in window
}
type Platform = "macos" | "windows" | "linux" | "ios" | "android" | null

/**
 * Detect the runtime OS via the existing `platform_info` Rust command
 * (returns "macos"|"windows"|"linux"|...). Falls back to null (no chrome)
 * in plain browser dev.
 */
function usePlatform(): Platform {
  const [platform, setPlatform] = useState<Platform>(null)

  useEffect(() => {
    if (!isTauriRuntime()) return
    let active = true
    void invoke<string>("platform_info")
      .then(value => {
        if (active) setPlatform(value as Platform)
      })
      .catch(() => {})
    return () => {
      active = false
    }
  }, [])

  return platform
}

/**
 * macOS Overlay titlebars have no system drag surface (the WKWebView covers
 * the whole window), so drags are initiated manually:
 * any primary mousedown inside the fusioned header whose target is not
 * interactive starts a window drag; a double click toggles maximize.
 * IMPORTANT: do NOT call `preventDefault()` here on macOS — Tauri's
 * `startDragging` uses `[NSWindow performWindowDragWithEvent: currentEvent]`,
 * which needs the live current mouse event; `preventDefault` cancels the
 * tracking and the window never moves. (Windows/Linux get dragging natively
 * from Tauri's injected `data-tauri-drag-region` script on the header.)
 */
function useMacDragRegion(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      if (event.clientY > headerBandHeight(FALLBACK_BAND_MAC)) return
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest(INTERACTIVE_SELECTOR)) return
      if (event.detail === 2) {
        void getCurrentWindow().toggleMaximize()
        return
      }
      if (event.detail === 1) void getCurrentWindow().startDragging()
    }
    document.addEventListener("mousedown", onMouseDown)
    return () => document.removeEventListener("mousedown", onMouseDown)
  }, [enabled])
}

/**
 * Win/Linux: the window is frameless (decorum on Windows, `decorations:false`
 * on Linux) but the app header stays the custom drag region.
 * WebKitGTK and WebView2 sometimes ignore `data-tauri-drag-region` on children
 * (direct element only), and on Linux the `app-region:drag` CSS does not always
 * work, so JS rescues dragging, limited to the real header height
 * (`h-11` = 44px) with the same `INTERACTIVE_SELECTOR` guard.
 */
function useWindowDragRegion(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const limit = headerBandHeight(FALLBACK_BAND_DESKTOP)
    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      if (event.clientY > limit) return
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest(INTERACTIVE_SELECTOR)) return
      // No preventDefault on non-interactive targets; startDragging needs the live event
      if (event.detail === 2) {
        void getCurrentWindow().toggleMaximize()
        return
      }
      if (event.detail === 1) void getCurrentWindow().startDragging()
    }
    document.addEventListener("mousedown", onMouseDown)
    return () => document.removeEventListener("mousedown", onMouseDown)
  }, [enabled])
}

type ResizeEdge =
  | "North"
  | "South"
  | "West"
  | "East"
  | "NorthWest"
  | "NorthEast"
  | "SouthWest"
  | "SouthEast"

const RESIZE_CURSOR: Record<ResizeEdge, string> = {
  North: "ns-resize",
  South: "ns-resize",
  West: "ew-resize",
  East: "ew-resize",
  NorthWest: "nwse-resize",
  SouthEast: "nwse-resize",
  NorthEast: "nesw-resize",
  SouthWest: "nesw-resize",
}

/**
 * Inner-edge grip band width, in CSS px.
 *
 * 8 gives the mouse room without eating UI. Native WM frames feel "better"
 * mostly because their grab area is forgiving; 6 was too tight in practice
 * (measured on the Cinnamon box, 2026-09-29). Exported so tests can cover
 * `resizeEdgeAt` without duplicating the number.
 */
const RESIZE_BAND = 8

/** Edge under the pointer, or null when far from any border. */
function resizeEdgeAt(x: number, y: number, band: number): ResizeEdge | null {
  const w = window.innerWidth
  const h = window.innerHeight
  const top = y <= band
  const bottom = y >= h - band
  const left = x <= band
  const right = x >= w - band

  if (top && left) return "NorthWest"
  if (top && right) return "NorthEast"
  if (bottom && left) return "SouthWest"
  if (bottom && right) return "SouthEast"
  if (top) return "North"
  if (bottom) return "South"
  if (left) return "West"
  if (right) return "East"
  return null
}

/**
 * Linux: the frameless window has **no resize grips** (the WM decorates
 * nothing). Tauri 2.12 exposes no `startResizing` either, so the app detects
 * the edge and Rust runs `gtk_window_begin_resize_drag` (`start_window_resize`).
 *
 * Edge cursors are ours too: with no WM frame nothing would set them.
 */
function useWindowResizeEdges(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const BAND = RESIZE_BAND

    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      // Interactive controls inside the band (caption buttons, toggles) keep
      // their clicks: resize must not win over a button that happens to sit
      // in the top 8px.
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest(INTERACTIVE_SELECTOR)) return
      const edge = resizeEdgeAt(event.clientX, event.clientY, BAND)
      if (!edge) return
      // Capture: GTK owns the drag, not the DOM. Stop the document-level
      // drag hook (bubble phase) from ALSO starting a window move on the
      // same press — two IPC calls for one mousedown.
      event.preventDefault()
      event.stopImmediatePropagation()
      void invoke("start_window_resize", { direction: edge }).catch(() => {})
    }
    const onMouseMove = (event: MouseEvent) => {
      const edge = resizeEdgeAt(event.clientX, event.clientY, BAND)
      document.documentElement.style.cursor = edge ? RESIZE_CURSOR[edge] : ""
    }

    document.addEventListener("mousedown", onMouseDown, true)
    document.addEventListener("mousemove", onMouseMove)
    return () => {
      document.removeEventListener("mousedown", onMouseDown, true)
      document.removeEventListener("mousemove", onMouseMove)
      document.documentElement.style.cursor = ""
    }
  }, [enabled])
}

export {
  isTauriRuntime,
  RESIZE_BAND,
  type ResizeEdge,
  resizeEdgeAt,
  useMacDragRegion,
  usePlatform,
  useWindowDragRegion,
  useWindowResizeEdges,
}
