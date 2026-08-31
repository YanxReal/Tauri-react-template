import { Button } from "@workspace/ui/components/button"
import { Languages, Moon, Sun } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useTheme } from "@/components/theme-provider"

export function Header() {
  const { t, i18n } = useTranslation()
  const { theme, setTheme } = useTheme()

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
    <header className="app-header sticky top-0 z-50 border-b bg-background/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
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
        </div>
      </div>
    </header>
  )
}
