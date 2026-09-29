import { render } from "@testing-library/react"
import { afterEach, describe, expect, it, vi } from "vitest"

import { TitleBar } from "./title-bar"

const invokeMock = vi.hoisted(() => vi.fn())

vi.mock("@tauri-apps/api/core", () => ({ invoke: invokeMock }))

beforeEach(() => {
  // usePlatform only probes inside the Tauri runtime.
  ;(window as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__ = {}
})

afterEach(() => {
  invokeMock.mockReset()
  document.documentElement.className = ""
  delete (window as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__
})

/**
 * Regression guard for the mobile header height: `html.ios` / `html.android`
 * drive the safe-area height rule in globals.css — before this, the class was
 * only added on desktop platforms and the mobile rule was dead code.
 */
describe("TitleBar platform classes", () => {
  it("adds html.ios for ios without desktop titlebar classes", async () => {
    invokeMock.mockResolvedValue("ios")
    render(<TitleBar />)

    await vi.waitFor(() =>
      expect(document.documentElement.classList.contains("ios")).toBe(true)
    )
    expect(document.documentElement.classList.contains("titlebar")).toBe(false)
    expect(document.documentElement.classList.contains("titlebar-win")).toBe(
      false
    )
  })

  it("adds html.android for android", async () => {
    invokeMock.mockResolvedValue("android")
    render(<TitleBar />)

    await vi.waitFor(() =>
      expect(document.documentElement.classList.contains("android")).toBe(true)
    )
    expect(document.documentElement.classList.contains("titlebar")).toBe(false)
  })

  it("adds html.linux + titlebar classes on desktop", async () => {
    invokeMock.mockResolvedValue("linux")
    render(<TitleBar />)

    await vi.waitFor(() =>
      expect(document.documentElement.classList.contains("linux")).toBe(true)
    )
    expect(document.documentElement.classList.contains("titlebar")).toBe(true)
    expect(document.documentElement.classList.contains("titlebar-win")).toBe(
      true
    )
  })

  it("ignores unknown platform strings (never throws on classList)", async () => {
    invokeMock.mockResolvedValue("not a platform")
    render(<TitleBar />)

    await vi.waitFor(() => expect(invokeMock).toHaveBeenCalled())
    expect(document.documentElement.className).toBe("")
  })
})
