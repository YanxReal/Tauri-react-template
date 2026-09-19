import { render, screen } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"

import { App } from "./App"
import { AppProviders } from "./components/app-providers"

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn().mockResolvedValue("Hello, Tauri!"),
}))

function renderApp() {
  return render(
    <AppProviders>
      <App />
    </AppProviders>
  )
}

describe("App", () => {
  it("renders header and main landmarks", () => {
    renderApp()
    expect(screen.getByRole("banner")).toBeInTheDocument()
    expect(screen.getByRole("main")).toBeInTheDocument()
    expect(screen.getByRole("contentinfo")).toBeInTheDocument()
  })

  it("has skip link for accessibility", () => {
    renderApp()
    expect(screen.getByText(/Skip to content/)).toBeInTheDocument()
  })

  it("renders bilingual toggle", () => {
    renderApp()
    expect(screen.getAllByRole("button").length).toBeGreaterThan(0)
  })
})
