import { getCurrentWindow } from "@tauri-apps/api/window"
import { Button } from "@workspace/ui/components/button"
import { Copy, Languages, Minus, Moon, Square, Sun, X } from "lucide-react"
import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { useTheme } from "@/components/theme-provider"
import { useVibrancy } from "@/components/vibrancy-provider"
import { isTauriRuntime, useMacDragRegion, usePlatform } from "./native-chrome"

export function Header() {
  const { t, i18n } = useTranslation()
  const { theme, setTheme } = useTheme()
  const { enabled: vibrancyEnabled, supported: vibrancySupported } =
    useVibrancy()
  const platform = usePlatform()

  const isMac = platform === "macos"
  const hasCaption = platform === "windows" || platform === "linux"
  const [maximized, setMaximized] = useState(false)

  // macOS Overlay: inicia el arrastre de la ventana en la banda superior.
  useMacDragRegion(isMac && isTauriRuntime())

  // Windows/Linux frameless: rastrea maximizado para el glyph restaurar.
  useEffect(() => {
    if (!hasCaption || !isTauriRuntime()) return
    const appWindow = getCurrentWindow()
    let active = true
    let stop: (() => void) | null = null
    const refresh = () => {
      void appWindow.isMaximized().then(value => {
        if (active) setMaximized(value)
      })
    }
    refresh()
    void appWindow
      .onResized(() => refresh())
      .then(unlisten => {
        if (active) stop = unlisten
        else unlisten()
      })
    return () => {
      active = false
      stop?.()
    }
  }, [hasCaption])

  const toggleLanguage = () => {
    const next = i18n.language === "es" ? "en" : "es"
    void i18n.changeLanguage(next)
    document.documentElement.lang = next
  }

  const toggleTheme = () => {
    const next = theme === "dark" ? "light" : "dark"
    setTheme(next)
  }

  const glassActive = vibrancyEnabled && vibrancySupported

  return (
    <header
      data-tauri-drag-region={hasCaption ? "" : undefined}
      className={`sticky top-0 z-50 border-b backdrop-blur ${
        glassActive ? "native-glass" : "bg-background/80"
      }`}
    >
      <div
        className={`mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6 ${
          isMac ? "pl-20 sm:pl-24" : ""
        }`}
      >
        <a
          href="/"
          className="flex items-center gap-2 font-semibold tracking-tight"
        >
          <span className="size-6 rounded bg-primary" aria-hidden />
          <span>{t("header.title")}</span>
        </a>

        <nav
          aria-label="Main navigation"
          className="hidden items-center gap-6 text-sm sm:flex"
        >
          <a
            href="#features"
            className="text-muted-foreground hover:text-foreground transition-colors"
          >
            {t("header.nav.features")}
          </a>
          <a
            href="https://tauri.app"
            target="_blank"
            rel="noreferrer"
            className="text-muted-foreground hover:text-foreground transition-colors"
          >
            {t("header.nav.docs")}
          </a>
          <a
            href="https://github.com"
            target="_blank"
            rel="noreferrer"
            className="text-muted-foreground hover:text-foreground transition-colors"
          >
            {t("header.nav.github")}
          </a>
        </nav>

        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={t("header.language")}
            onClick={toggleLanguage}
            title={t("header.language")}
          >
            <Languages className="size-4" />
            <span className="sr-only">
              {t("header.language")}: {i18n.language.toUpperCase()}
            </span>
            <span aria-hidden className="hidden text-xs font-medium sm:inline">
              {i18n.language.toUpperCase()}
            </span>
          </Button>

          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={t("header.toggleTheme")}
            onClick={toggleTheme}
          >
            <Sun className="hidden size-4 dark:block" />
            <Moon className="size-4 dark:hidden" />
          </Button>

          {hasCaption && (
            <div className="ml-2 flex items-center gap-0.5 border-l pl-2">
              <CaptionButton
                label={t("header.minimize")}
                onClick={() => void getCurrentWindow().minimize()}
              >
                <Minus className="size-4" />
              </CaptionButton>
              <CaptionButton
                label={maximized ? t("header.restore") : t("header.maximize")}
                onClick={() => void getCurrentWindow().toggleMaximize()}
              >
                {maximized ? (
                  <Copy className="size-3.5" />
                ) : (
                  <Square className="size-3.5" />
                )}
              </CaptionButton>
              <CaptionButton
                label={t("header.close")}
                danger
                onClick={() => void getCurrentWindow().close()}
              >
                <X className="size-4" />
              </CaptionButton>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}

function CaptionButton({
  label,
  danger,
  onClick,
  children,
}: {
  label: string
  danger?: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      data-no-drag
      aria-label={label}
      onClick={onClick}
      className={`flex h-7 w-9 items-center justify-center rounded transition-colors ${
        danger
          ? "text-muted-foreground hover:bg-red-600 hover:text-white"
          : "text-muted-foreground hover:bg-muted hover:text-foreground"
      }`}
    >
      {children}
    </button>
  )
}
