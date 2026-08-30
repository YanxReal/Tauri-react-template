import { useTranslation } from "react-i18next"

export function Footer() {
  const { t } = useTranslation()
  const year = new Date().getFullYear()

  return (
    <footer className="border-t">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-6 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <p>
          © {year} {t("header.title")}. {t("footer.rights")}
        </p>
        <div className="flex items-center gap-4">
          <span>{t("footer.builtWith")}</span>
          <nav aria-label="Footer navigation" className="flex gap-3">
            <a
              href="/privacy"
              className="hover:text-foreground hover:underline underline-offset-4"
            >
              {t("footer.privacy")}
            </a>
            <a
              href="/terms"
              className="hover:text-foreground hover:underline underline-offset-4"
            >
              {t("footer.terms")}
            </a>
          </nav>
        </div>
      </div>
    </footer>
  )
}
