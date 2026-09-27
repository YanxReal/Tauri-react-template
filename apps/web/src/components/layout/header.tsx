import { Button } from "@workspace/ui/components/button"
import { GlassButton } from "@workspace/ui/components/glass-button"
import { Languages, Moon, Sun } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"
import { useTheme } from "@/components/theme-provider"
import { usePlatform, useWindowDragRegion } from "./native-chrome"
import { WindowControls } from "./window-controls"

/**
 * Hover de los controles del header (idioma / tema). Ni el `ghost` de shadcn
 * (`bg-muted` / `dark:bg-muted/50`) ni el de glass (`white/10` → apenas 6 %
 * negro tras la inversión en claro) se leen sobre la banda de la titlebar: el
 * primero desaparece en oscuro y el segundo en claro. Usamos el mismo lenguaje
 * que los caption buttons (negro/10 en claro) y subimos el oscuro a blanco/15
 * para que el efecto se vea igual de claro en los dos temas.
 */
const HEADER_CONTROL_HOVER = "hover:bg-black/10 dark:hover:bg-white/15"

/**
 * La titlebar de Win/Linux es frameless: el header ES la banda, así que su alto
 * tiene que ser fijo. Antes sólo estaba `h-14` y el flex-column del shell la
 * comprimía hasta su min-content, o sea que el alto lo decidía el contenido de
 * cada página (44px — lo que medía de facto). Con `shrink-0` + `h-11` la banda
 * queda clavada en esos 44px, con aire suficiente para los botones de 32px sin
 * que el pill crezca fuera de la barra. macOS conserva sus 52px (traffic
 * lights) y móvil/web sus 56px.
 */
const HEADER_HEIGHT = {
  macos: "h-[52px]",
  desktop: "h-11",
  mobile: "h-14",
} as const

/**
 * Unified header — Prestly fusioned-titlebar pattern.
 *
 * The header occupies the FULL top of the window on every platform:
 *
 * macOS (`titleBarStyle: Overlay`): a 52px band that hosts the overlay
 * traffic lights on the left — `pl-[96px] sm:pl-[108px]` keeps the logo
 * clear of the dots. Dragging comes from the document-level mousedown
 * listener (`useMacDragRegion` in native-chrome.ts).
 *
 * Windows (`decorations: false` + decorum overlay) and Linux (`decorations:
 * false`, frameless — esquinas cuadradas del sistema, decisión consciente):
 * this header IS the titlebar — one fixed 44px row (Edge / VS Code style)
 * that stays draggable through `data-tauri-drag-region` + `useWindowDragRegion`
 * (Prestly band) and hosts the caption buttons (`WindowControls`).
 */
export function Header() {
  const { t, i18n } = useTranslation()
  const { theme, setTheme } = useTheme()
  const platform = usePlatform()
  const { enabled: glassEnabled } = useGlassCards()
  const isMac = platform === "macos"
  const isWinLinux = platform === "windows" || platform === "linux"
  const headerHeight = isMac
    ? HEADER_HEIGHT.macos
    : isWinLinux
      ? HEADER_HEIGHT.desktop
      : HEADER_HEIGHT.mobile

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
      className={`app-header relative flex shrink-0 items-center rounded-none border-b backdrop-blur pt-[env(safe-area-inset-top)] md:sticky md:top-0 md:z-40 ${
        glassEnabled ? "border-white/20 bg-white/10" : "bg-background"
      } ${headerHeight}`}
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
              size="sm"
              className={`hover:scale-100 active:scale-100 ${HEADER_CONTROL_HOVER}`}
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
              size="sm"
              className={HEADER_CONTROL_HOVER}
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
              className={`h-8 w-8 hover:scale-100 active:scale-100 ${HEADER_CONTROL_HOVER}`}
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
              className={HEADER_CONTROL_HOVER}
              aria-label={t("header.toggleTheme")}
              onClick={toggleTheme}
            >
              <Sun className="hidden size-4 dark:block" />
              <Moon className="size-4 dark:hidden" />
            </Button>
          )}
        </div>
      </div>
      {/* Win/Linux: caption buttons propias (titlebar dibujada por la app) */}
      {isWinLinux && <WindowControls />}
    </header>
  )
}
