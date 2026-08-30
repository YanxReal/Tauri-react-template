import { Code2, Languages, Layers } from "lucide-react"
import { useTranslation } from "react-i18next"

const icons = [Code2, Languages, Layers] as const

export function Features() {
  const { t } = useTranslation()
  const items = t("features.items", { returnObjects: true }) as Array<{
    title: string
    description: string
  }>

  return (
    <section
      id="features"
      aria-labelledby="features-heading"
      className="mx-auto max-w-6xl px-4 py-8 sm:px-6"
    >
      <h2
        id="features-heading"
        className="text-xl font-semibold tracking-tight"
      >
        {t("features.title")}
      </h2>

      <ul className="mt-6 grid gap-4 sm:grid-cols-3">
        {items.map((item, idx) => {
          const Icon = icons[idx] ?? Code2
          return (
            <li key={item.title} className="rounded-xl border bg-card p-5">
              <div className="flex size-9 items-center justify-center rounded-lg bg-muted">
                <Icon className="size-4" aria-hidden />
              </div>
              <h3 className="mt-3 font-medium">{item.title}</h3>
              <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
                {item.description}
              </p>
            </li>
          )
        })}
      </ul>
    </section>
  )
}
