import { render, screen } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"

import { ErrorBoundary } from "./error-boundary"

function Boom(): never {
  throw new Error("boom")
}

describe("ErrorBoundary", () => {
  it("renders children when nothing throws", () => {
    render(
      <ErrorBoundary>
        <span>safe</span>
      </ErrorBoundary>
    )

    expect(screen.getByText("safe")).toBeInTheDocument()
  })

  it("renders the keyed fallback when a child throws", () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {})

    render(
      <ErrorBoundary>
        <Boom />
      </ErrorBoundary>
    )

    expect(screen.getByRole("alert")).toBeInTheDocument()
    expect(
      screen.getByRole("button", { name: /reload|recargar/i })
    ).toBeInTheDocument()
    consoleError.mockRestore()
  })
})
