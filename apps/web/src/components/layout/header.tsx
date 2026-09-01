import { getCurrentWindow } from "@tauri-apps/api/window"
import { Button } from "@workspace/ui/components/button"
import { GlassButton } from "@workspace/ui/components/glass-button"
import { Copy, Languages, Minus, Moon, Square, Sun, X } from "lucide-react"
import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"
import { useTheme } from "@/components/theme-provider"
import { usePlatform } from "./native-chrome"

function runWindowAction(action: "minimize" | "maximize" | "close"): void {
  const w = getCurrentWindow()
  if (action === "minimize") void w.minimize()
  else if (action === "maximize") void w.toggleMaximize()
  else void w.close()
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
      aria-label={label}
      onClick={onClick}
      className={`flex h-full w-[46px] items-center justify-center transition-colors ${
        danger
          ? "text-foreground hover:bg-[#e81123] hover:text-white dark:text-white dark:hover:bg-[#e81123]"
          : "text-foreground hover:bg-black/10 hover:text-foreground dark:text-white dark:hover:bg-white/10 dark:hover:text-white"
      }`}
    >
      {children}
    </button>
  )
}

/**
 * Unified header — Prestly fusioned-titlebar pattern.
 *
 * The header occupies the FULL top of the window on every platform:
 *
 * macOS (`titleBarStyle: Overlay`): the header is tall enough to sit
 * BELOW the native traffic lights (`h-[76px]` = 20px traffic-light zone +
 * 56px content).  `pl-20 sm:pl-24` keeps the logo clear of the dots.
 * Dragging comes from the document-level mousedown listener
 * (`useMacDragRegion` in TitleBar).
 *
 * Windows/Linux (`decorations: false`): the header is a single 56px row
 * with caption buttons (minimize / maximize / close) at the right.
 * `data-tauri-drag-region` lets Tauri's injected script handle
 * dragging + double-click-to-maximize natively.
 */
export function Header() {
  const { t, i18n } = useTranslation()
  const { theme, setTheme } = useTheme()
  const platform = usePlatform()
  const { enabled: glassEnabled } = useGlassCards()
  const isMac = platform === "macos"
  const isWinLinux = platform === "windows" || platform === "linux"
  const [maximized, setMaximized] = useState(false)

  useEffect(() => {
    if (!isWinLinux) return
    const appWindow = getCurrentWindow()
    let active = true
    let stop: (() => void) | null = null
    const refresh = () => {
      void appWindow.isMaximized().then(v => {
        if (active) setMaximized(v)
      })
    }
    refresh()
    void appWindow.onResized(() => refresh()).then(u => {
      if (active) stop = u
      else u()
    })
    return () => {
      active = false
      stop?.()
    }
  }, [isWinLinux])

  const toggleLanguage = () => {
    const next = i18n.language === "es" ? "en" : "es"
    void i18n.changeLanguage(next)
    document.documentElement.lang = next
  }

  const toggleTheme = () => {
    const next = theme === "dark" ? "light" : "dark"
    setTheme(next)
  }

  return (
    <header
      className={`app-header relative flex items-center border-b backdrop-blur pt-[env(safe-area-inset-top)] md:sticky md:top-0 md:z-40 ${
        glassEnabled ? "border-white/20 bg-white/10" : "bg-background"
      } ${isMac ? "h-[64px]" : "h-14"}`}
      {...(isWinLinux ? { "data-tauri-drag-region": true } : {})}
    >
      {/* Capa de arrastre detrás del contenido — solo Win/Linux */}
      {isWinLinux && (
        <div
          data-tauri-drag-region
          className="absolute inset-0"
          aria-hidden
        />
      )}
      <div
        className={`relative z-10 flex min-w-0 flex-1 items-center justify-between gap-3 px-4 sm:px-6 ${
          isMac
            ? "mx-auto w-full max-w-6xl h-full pl-[96px] sm:pl-[108px]"
            : "mx-auto h-full w-full max-w-6xl"
        }`}
      >
        <a
          href="/"
          className="flex min-w-0 items-center gap-2 font-semibold tracking-tight"
        >
          <span className="size-6 shrink-0 rounded bg-primary" aria-hidden />
          <span
            className={`truncate ${glassEnabled ? "text-white" : undefined}`}
            title={t("header.title")}
          >
            {t("header.title")}
          </span>
        </a>

        <nav
          aria-label="Main navigation"
          className="hidden items-center gap-6 text-sm sm:flex"
        >
          <a
            href="https://ui.shadcn.com"
            target="_blank"
            rel="noreferrer"
            className={`${
              glassEnabled
                ? "text-white/70 hover:text-white"
                : "text-muted-foreground hover:text-foreground"
            } transition-colors`}
          >
            Shadcn UI
          </a>
          <a
            href="https://ui.eindev.ir"
            target="_blank"
            rel="noreferrer"
            className={`${
              glassEnabled
                ? "text-white/70 hover:text-white"
                : "text-muted-foreground hover:text-foreground"
            } transition-colors`}
          >
            EinUI
          </a>
          <a
            href="https://github.com/YanxReal/tauri-react-template"
            target="_blank"
            rel="noreferrer"
            className={`${
              glassEnabled
                ? "text-white/70 hover:text-white"
                : "text-muted-foreground hover:text-foreground"
            } transition-colors`}
          >
            {t("header.nav.github")}
          </a>
        </nav>

        <div className="flex shrink-0 items-center gap-1 sm:gap-2">
          {isWinLinux && <span className="hidden lg:block w-3" aria-hidden />}
          {glassEnabled ? (
            <GlassButton
              variant="ghost"
              size="icon"
              aria-label={t("header.language")}
              onClick={toggleLanguage}
              title={t("header.language")}
            >
              <Languages className="size-4" />
              <span className="sr-only">
                {t("header.language")}: {i18n.language.toUpperCase()}
              </span>
              <span
                aria-hidden
                className="hidden text-xs font-medium sm:inline"
              >
                {i18n.language.toUpperCase()}
              </span>
            </GlassButton>
          ) : (
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
              <span
                aria-hidden
                className="hidden text-xs font-medium sm:inline"
              >
                {i18n.language.toUpperCase()}
              </span>
            </Button>
          )}

          {glassEnabled ? (
            <GlassButton
              variant="ghost"
              size="icon"
              aria-label={t("header.toggleTheme")}
              onClick={toggleTheme}
            >
              <Sun className="hidden size-4 dark:block" />
              <Moon className="size-4 dark:hidden" />
            </GlassButton>
          ) : (
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={t("header.toggleTheme")}
              onClick={toggleTheme}
            >
              <Sun className="hidden size-4 dark:block" />
              <Moon className="size-4 dark:hidden" />
            </Button>
          )}
        </div>
      </div>
      {/* Caption buttons — Win/Linux: flex hermano, misma fila, nunca overlay, despegados 8px */}
      {isWinLinux && (
        <div className="relative z-20 flex h-full shrink-0 items-stretch pr-2">
          <CaptionButton
            label={t("header.minimize")}
            onClick={() => runWindowAction("minimize")}
          >
            <Minus className="size-3.5" />
          </CaptionButton>
          <CaptionButton
            label={maximized ? t("header.restore") : t("header.maximize")}
            onClick={() => runWindowAction("maximize")}
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
            onClick={() => runWindowAction("close")}
          >
            <X className="size-3.5" />
          </CaptionButton>
        </div>
      )}
    </header>
  )
}
