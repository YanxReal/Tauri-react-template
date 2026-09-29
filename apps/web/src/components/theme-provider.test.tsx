import { render, screen } from "@testing-library/react"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { ThemeProvider, useTheme } from "./theme-provider"

function Probe() {
  const { resolvedTheme, theme, setTheme } = useTheme()
  return (
    <>
      <span data-testid="theme">{theme}</span>
      <span data-testid="resolved">{resolvedTheme}</span>
      <button onClick={() => setTheme("light")}>to-light</button>
    </>
  )
}

function renderProbe() {
  return render(
    <ThemeProvider>
      <Probe />
    </ThemeProvider>
  )
}

const originalMatchMedia = window.matchMedia

beforeEach(() => {
  localStorage.clear()
  // System = dark for these tests.
  Object.defineProperty(window, "matchMedia", {
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches: query.includes("prefers-color-scheme: dark"),
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  })
})

afterEach(() => {
  Object.defineProperty(window, "matchMedia", {
    writable: true,
    value: originalMatchMedia,
  })
  document.documentElement.className = ""
})

describe("ThemeProvider resolvedTheme", () => {
  it("resolves 'system' against prefers-color-scheme (dark)", () => {
    renderProbe()
    expect(screen.getByTestId("theme").textContent).toBe("system")
    expect(screen.getByTestId("resolved").textContent).toBe("dark")
  })

  it("exposes the resolved value so a toggle from system+dark actually flips", async () => {
    renderProbe()
    // The header's toggle derives `next` from resolvedTheme; with "system"
    // + dark it must go LIGHT (regression: it wrote "dark" — no-op).
    expect(screen.getByTestId("resolved").textContent).toBe("dark")
    screen.getByText("to-light").click()
    await vi.waitFor(() =>
      expect(screen.getByTestId("resolved").textContent).toBe("light")
    )
    expect(document.documentElement.classList.contains("light")).toBe(true)
  })
})
