import { render, screen } from "@testing-library/react"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { GlassCardsProvider, useGlassCards } from "./glass-cards-provider"

const invokeMock = vi.hoisted(() => vi.fn())
vi.mock("@tauri-apps/api/core", () => ({ invoke: invokeMock }))

function Probe() {
  const { enabled, supported } = useGlassCards()
  return (
    <>
      <span data-testid="enabled">{String(enabled)}</span>
      <span data-testid="supported">{String(supported)}</span>
    </>
  )
}

function renderProbe() {
  return render(
    <GlassCardsProvider>
      <Probe />
    </GlassCardsProvider>
  )
}

beforeEach(() => {
  localStorage.clear()
})

afterEach(() => {
  invokeMock.mockReset()
  document.documentElement.className = ""
  delete (window as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__
})

/**
 * Regression guard: with a stored preference ON, the glass class must not be
 * applied until the platform is known in the Tauri shell — otherwise Linux
 * (WebKitGTK) flashes backdrop-blur for one IPC round-trip (the exact
 * scenario the glass veto exists for).
 */
describe("GlassCardsProvider platform gating", () => {
  it("collapses to disabled on linux even with the stored preference ON", async () => {
    ;(window as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__ = {}
    localStorage.setItem("glass-cards", "1")
    invokeMock.mockResolvedValue("linux")

    renderProbe()

    // Before the platform resolves: no glass class yet (no flash).
    expect(document.documentElement.classList.contains("glass-cards")).toBe(
      false
    )

    await vi.waitFor(() =>
      expect(screen.getByTestId("supported").textContent).toBe("false")
    )
    expect(screen.getByTestId("enabled").textContent).toBe("false")
    expect(document.documentElement.classList.contains("glass-cards")).toBe(
      false
    )
  })

  it("enables glass on supported platforms when stored ON", async () => {
    ;(window as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__ = {}
    localStorage.setItem("glass-cards", "1")
    invokeMock.mockResolvedValue("macos")

    renderProbe()

    await vi.waitFor(() =>
      expect(screen.getByTestId("enabled").textContent).toBe("true")
    )
    expect(document.documentElement.classList.contains("glass-cards")).toBe(
      true
    )
  })

  it("applies immediately in the browser (no Tauri IPC to wait for)", async () => {
    localStorage.setItem("glass-cards", "1")
    invokeMock.mockResolvedValue("linux") // irrelevant: no Tauri runtime

    renderProbe()

    await vi.waitFor(() =>
      expect(screen.getByTestId("enabled").textContent).toBe("true")
    )
  })
})
