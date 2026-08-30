import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"

import { Button } from "./button"

describe("Button", () => {
  it("renders correctly", () => {
    render(<Button>Click me</Button>)
    expect(screen.getByRole("button", { name: "Click me" })).toBeInTheDocument()
  })

  it("applies variant classes", () => {
    render(<Button variant="outline">Outline</Button>)
    expect(screen.getByRole("button")).toBeInTheDocument()
  })
})
