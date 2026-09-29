import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"

export function Footer() {
  const { t } = useTranslation()
  const { enabled: glassEnabled } = useGlassCards()
  const year = new Date().getFullYear()

  return (
    <footer
      className={`rounded-none border-t backdrop-blur-xl ${
        glassEnabled ? "border-white/20 bg-white/10" : "bg-background"
      }`}
    >
      <div
        className={`mx-auto flex max-w-6xl flex-col gap-2 px-4 py-6 text-sm sm:flex-row sm:items-center sm:justify-between sm:px-6 ${
          glassEnabled ? "text-white/60" : "text-muted-foreground"
        }`}
      >
        <p>{t("footer.copyright", { year })}</p>
        <span>{t("footer.builtWith")}</span>
      </div>
    </footer>
  )
}
