import { invoke } from "@tauri-apps/api/core"
import { Button } from "@workspace/ui/components/button"
import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { Features } from "@/components/layout/features"
import { Footer } from "@/components/layout/footer"
import { Header } from "@/components/layout/header"
import { Hero } from "@/components/layout/hero"
import { VibrancyToggle } from "@/components/layout/vibrancy-toggle"

export function App() {
  const { t, i18n } = useTranslation()
  const [greet, setGreet] = useState<string | null>(null)

  useEffect(() => {
    document.documentElement.lang = i18n.language
  }, [i18n.language])

  async function handleGreet() {
    try {
      const message = await invoke<string>("greet", { name: "Tauri" })
      setGreet(message)
    } catch {
      setGreet("Tauri API not available in browser")
    }
  }

  return (
    <div className="flex min-h-svh flex-col">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-primary focus:px-3 focus:py-2 focus:text-primary-foreground"
      >
        Skip to content / Saltar al contenido
      </a>

      <Header />

      <main id="main-content" className="flex-1">
        <Hero />
        <Features />

        <section
          aria-labelledby="status-heading"
          className="mx-auto max-w-6xl px-4 py-8 sm:px-6"
        >
          <div className="rounded-xl border bg-card p-6">
            <h2 id="status-heading" className="font-semibold">
              {t("status.title")}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {t("status.description")}
            </p>
            <p className="text-sm text-muted-foreground">{t("status.note")}</p>

            <div className="mt-4 flex flex-wrap items-center gap-3">
              <Button onClick={handleGreet}>Button</Button>
              <Button variant="outline" onClick={handleGreet}>
                Greet from Rust
              </Button>
            </div>

            <div className="mt-4 flex items-center gap-3">
              <VibrancyToggle />
            </div>

            {greet && (
              <p className="mt-3 text-sm" role="status" aria-live="polite">
                {t("status.tauriNote", { message: greet })}
              </p>
            )}
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}
