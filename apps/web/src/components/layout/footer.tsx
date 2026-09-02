import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"

export function Footer() {
  const { i18n } = useTranslation()
  const { enabled: glassEnabled } = useGlassCards()
  const year = new Date().getFullYear()
  const linkCls = `hover:underline underline-offset-4 ${glassEnabled ? "hover:text-white" : "hover:text-foreground"}`

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
        <p>© {year} Yanx Studio</p>
        <span>
          {i18n.language.startsWith("es") ? "Hecho con " : "Built with "}
          <a
            href="https://github.com/tauri-apps/tauri"
            target="_blank"
            rel="noreferrer"
            className={linkCls}
          >
            Tauri
          </a>
          ,{" "}
          <a
            href="https://react.dev"
            target="_blank"
            rel="noreferrer"
            className={linkCls}
          >
            React
          </a>
          {i18n.language.startsWith("es") ? " y " : " and "}
          <a
            href="https://vite.dev"
            target="_blank"
            rel="noreferrer"
            className={linkCls}
          >
            Vite
          </a>
          .
        </span>
      </div>
    </footer>
  )
}
