import { render, screen } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"

import { App } from "./App"
import { AppProviders } from "./components/app-providers"

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn((cmd: string) =>
    Promise.resolve(cmd === "platform_info" ? "web" : "Hello, Tauri!")
  ),
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
    // react-i18next is mocked globally (t returns the key).
    expect(screen.getByText("app.skipToContent")).toBeInTheDocument()
  })

  it("renders bilingual toggle", () => {
    renderApp()
    expect(screen.getAllByRole("button").length).toBeGreaterThan(0)
  })
})
