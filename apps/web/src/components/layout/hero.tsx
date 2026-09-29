import { GlassBadge } from "@workspace/ui/components/glass-badge"
import { GlassButton } from "@workspace/ui/components/glass-button"
import { ArrowRight, Sparkles } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"

export function Hero() {
  const { t } = useTranslation()
  const { enabled: glassEnabled } = useGlassCards()

  return (
    <section
      aria-labelledby="hero-heading"
      className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16"
    >
      <div className="flex max-w-3xl flex-col gap-6">
        {glassEnabled ? (
          <GlassBadge variant="default" className="gap-2">
            <Sparkles className="size-3.5" aria-hidden />
            {t("hero.badge")}
          </GlassBadge>
        ) : (
          <div className="inline-flex w-fit items-center gap-2 rounded-full border bg-muted px-3 py-1 text-xs font-medium">
            <Sparkles className="size-3.5" aria-hidden />
            {t("hero.badge")}
          </div>
        )}

        <h1
          id="hero-heading"
          className="text-4xl font-bold tracking-tight sm:text-5xl"
        >
          {t("hero.title")}
        </h1>

        <p className="text-lg leading-relaxed text-muted-foreground">
          {t("hero.description")}
        </p>

        <div className="flex flex-wrap items-center gap-3">
          {glassEnabled ? (
            <GlassButton asChild size="lg" variant="primary">
              <a
                href="https://tauri.app/start/"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 whitespace-nowrap"
              >
                {t("hero.ctaPrimary")}
                <ArrowRight className="size-4 shrink-0" aria-hidden />
              </a>
            </GlassButton>
          ) : (
            <a
              href="https://tauri.app/start/"
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-10 items-center justify-center gap-2 whitespace-nowrap rounded-4xl bg-primary px-4 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/80"
            >
              {t("hero.ctaPrimary")}
              <ArrowRight className="size-4 shrink-0" aria-hidden />
            </a>
          )}

          {glassEnabled ? (
            <GlassButton asChild size="lg" variant="outline">
              <a href="https://tauri.app" target="_blank" rel="noreferrer">
                {t("hero.ctaSecondary")}
              </a>
            </GlassButton>
          ) : (
            <a
              href="https://tauri.app"
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-10 items-center justify-center rounded-4xl border border-border bg-background px-4 text-sm font-medium transition-colors hover:bg-muted hover:text-foreground"
            >
              {t("hero.ctaSecondary")}
            </a>
          )}
        </div>

        <p className="font-mono text-xs text-muted-foreground">
          {t("hero.hint")} ·{" "}
          <kbd className="rounded border bg-muted px-1.5 py-0.5">D</kbd>
        </p>
      </div>
    </section>
  )
}
