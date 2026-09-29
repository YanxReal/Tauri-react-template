import { Button } from "@workspace/ui/components/button"
import * as React from "react"

import i18n from "@/i18n/config"

type ErrorBoundaryState = { hasError: boolean }

/**
 * Last-resort UI guard: a render error anywhere below unmounts the tree, so
 * without a boundary the user faces a blank window with no way back. The
 * fallback reads the shared i18n instance (class components cannot use hooks)
 * and reloads the webview.
 */
export class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { hasError: false }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true }
  }

  componentDidCatch(error: unknown, info: React.ErrorInfo) {
    console.error("Unhandled UI error:", error, info.componentStack)
  }

  render() {
    if (!this.state.hasError) {
      return this.props.children
    }

    return (
      <div
        role="alert"
        className="flex min-h-svh flex-col items-center justify-center gap-3 p-8 text-center"
      >
        <h1 className="text-lg font-semibold">{i18n.t("error.title")}</h1>
        <p className="max-w-md text-sm text-muted-foreground">
          {i18n.t("error.body")}
        </p>
        <Button onClick={() => window.location.reload()}>
          {i18n.t("error.reload")}
        </Button>
      </div>
    )
  }
}
