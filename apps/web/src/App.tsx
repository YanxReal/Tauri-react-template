import { invoke } from "@tauri-apps/api/core"
import { Button } from "@workspace/ui/components/button"
import { GlassButton } from "@workspace/ui/components/glass-button"
import {
  GlassCard,
  GlassCardContent,
} from "@workspace/ui/components/glass-card"
import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"
import { Features } from "@/components/layout/features"
import { Footer } from "@/components/layout/footer"
import { GlassCardsToggle } from "@/components/layout/glass-cards-toggle"
import { Header } from "@/components/layout/header"
import { Hero } from "@/components/layout/hero"
import { TitleBar } from "@/components/layout/title-bar"
import { VibrancyToggle } from "@/components/layout/vibrancy-toggle"

export function App() {
  const { t, i18n } = useTranslation()
  const { enabled: glassEnabled } = useGlassCards()
  const [greet, setGreet] = useState<string | null>(null)

  useEffect(() => {
    document.documentElement.lang = i18n.language
  }, [i18n.language])

  async function handleGreet() {
    try {
      const message = await invoke<string>("greet", { name: "Tauri" })
      // Traduce la respuesta del backend cuando la UI está en español
      const translated =
        i18n.language.startsWith("es") && message.includes("Hello,")
          ? message
              .replace("Hello,", "¡Hola,")
              .replace(
                "You've been greeted from Rust!",
                "¡Te ha saludado Rust!"
              )
          : message
      setGreet(translated)
    } catch {
      setGreet(t("status.greetFallback"))
    }
  }

  return (
    <div className="app-shell flex min-h-svh flex-col">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-primary focus:px-3 focus:py-2 focus:text-primary-foreground"
      >
        Skip to content / Saltar al contenido
      </a>

      <TitleBar />
      <Header />

      <main id="main-content" className="flex-1">
        <Hero />
        <Features />

        <section
          aria-labelledby="status-heading"
          className="mx-auto max-w-6xl px-4 py-8 sm:px-6"
        >
          {glassEnabled ? (
            <GlassCard>
              <GlassCardContent className="p-6">
                <h2 id="status-heading" className="font-semibold">
                  {t("status.title")}
                </h2>
                <p className="mt-1 text-sm text-white/60">
                  {t("status.description")}
                </p>
                <p className="mt-1 text-sm text-white/60">{t("status.note")}</p>

                <div className="mt-4 flex flex-wrap items-center gap-3">
                  <GlassButton variant="outline" onClick={handleGreet}>
                    {t("status.greetButton")}
                  </GlassButton>
                </div>

                <div className="mt-4 flex items-center gap-3">
                  <VibrancyToggle />
                  <GlassCardsToggle />
                </div>

                {greet && (
                  <p
                    className="mt-3 text-sm text-white/80"
                    role="status"
                    aria-live="polite"
                  >
                    {t("status.tauriNote", { message: greet })}
                  </p>
                )}
              </GlassCardContent>
            </GlassCard>
          ) : (
            <div className="rounded-xl border bg-card p-6">
              <h2 id="status-heading" className="font-semibold">
                {t("status.title")}
              </h2>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("status.description")}
              </p>
              <p className="mt-1 text-sm text-muted-foreground">
                {t("status.note")}
              </p>

              <div className="mt-4 flex flex-wrap items-center gap-3">
                <Button variant="outline" onClick={handleGreet}>
                  {t("status.greetButton")}
                </Button>
              </div>

              <div className="mt-4 flex items-center gap-3">
                <VibrancyToggle />
                <GlassCardsToggle />
              </div>

              {greet && (
                <p className="mt-3 text-sm" role="status" aria-live="polite">
                  {t("status.tauriNote", { message: greet })}
                </p>
              )}
            </div>
          )}
        </section>
      </main>

      <Footer />
    </div>
  )
}
