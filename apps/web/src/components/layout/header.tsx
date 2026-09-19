import { Button } from "@workspace/ui/components/button"
import { GlassButton } from "@workspace/ui/components/glass-button"
import { Languages, Moon, Sun } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"
import { useTheme } from "@/components/theme-provider"
import { usePlatform, useWindowDragRegion } from "./native-chrome"
import { WindowControls } from "./window-controls"

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
 * Windows (`decorations: false` + decorum overlay): this header IS the
 * titlebar — one 56px row that stays draggable through
 * `data-tauri-drag-region` + `useWindowDragRegion` (Prestly band) and hosts
 * the caption buttons (`WindowControls`).
 *
 * Linux (`decorations: true`): the OS draws the native titlebar with its own
 * buttons, so the header is pure app chrome — still one 56px row, still
 * draggable through the same Prestly band.
 */
export function Header() {
  const { t, i18n } = useTranslation()
  const { theme, setTheme } = useTheme()
  const platform = usePlatform()
  const { enabled: glassEnabled } = useGlassCards()
  const isMac = platform === "macos"
  const isWindows = platform === "windows"
  const isWinLinux = platform === "windows" || platform === "linux"

  useWindowDragRegion(isWinLinux)

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
      className={`app-header relative flex items-center rounded-none border-b backdrop-blur pt-[env(safe-area-inset-top)] md:sticky md:top-0 md:z-40 ${
        glassEnabled ? "border-white/20 bg-white/10" : "bg-background"
      } ${isMac ? "h-[52px]" : "h-14"}`}
      {...(isWinLinux ? { "data-tauri-drag-region": true } : {})}
    >
      {/* Capa de arrastre detrás del contenido — solo Win/Linux */}
      {isWinLinux && (
        <div data-tauri-drag-region className="absolute inset-0" aria-hidden />
      )}
      <div
        className={`relative z-10 flex min-w-0 flex-1 items-center justify-between gap-3 px-4 sm:px-6 ${
          isMac
            ? "mx-auto w-full max-w-6xl h-full pl-[96px] sm:pl-[108px]"
            : "mx-auto h-full w-full max-w-6xl"
        }`}
        {...(isWinLinux ? { "data-tauri-drag-region": true } : {})}
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
            ShadcnUI
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
      {/* Windows: caption buttons propias (ventana frameless con decorum) */}
      {isWindows && <WindowControls />}
    </header>
  )
}
