import { Button } from "@workspace/ui/components/button"
import { ArrowRight, Sparkles } from "lucide-react"
import { useTranslation } from "react-i18next"

export function Hero() {
  const { t } = useTranslation()

  return (
    <section
      aria-labelledby="hero-heading"
      className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16"
    >
      <div className="flex max-w-3xl flex-col gap-6">
        <div className="inline-flex w-fit items-center gap-2 rounded-full border bg-muted px-3 py-1 text-xs font-medium">
          <Sparkles className="size-3.5" aria-hidden />
          {t("hero.badge")}
        </div>

        <h1
          id="hero-heading"
          className="text-4xl font-bold tracking-tight sm:text-5xl"
        >
          {t("hero.title")}
        </h1>

        <p className="text-lg leading-relaxed text-muted-foreground">
          {t("hero.description")}
        </p>

        <div className="flex flex-wrap gap-3">
          <Button size="lg">
            {t("hero.ctaPrimary")} <ArrowRight className="size-4" aria-hidden />
          </Button>
          <a
            href="https://tauri.app"
            target="_blank"
            rel="noreferrer"
            className="inline-flex h-10 items-center justify-center rounded-4xl border border-border bg-background px-4 text-sm font-medium transition-colors hover:bg-muted hover:text-foreground"
          >
            {t("hero.ctaSecondary")}
          </a>
        </div>

        <p className="font-mono text-xs text-muted-foreground">
          {t("hero.hint", { key: "D" })} ·{" "}
          <kbd className="rounded border bg-muted px-1.5 py-0.5">D</kbd>
        </p>
      </div>
    </section>
  )
}
