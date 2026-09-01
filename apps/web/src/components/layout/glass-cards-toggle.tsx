import { Switch } from "@workspace/ui/components/switch"
import { Shapes } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"

export function GlassCardsToggle() {
  const { t } = useTranslation()
  const { enabled, setEnabled } = useGlassCards()

  return (
    <span className="inline-flex items-center gap-2 text-sm">
      <Shapes className="size-4 text-muted-foreground" aria-hidden />
      <span className="text-muted-foreground">{t("glassCards.label")}</span>
      <Switch
        checked={enabled}
        onCheckedChange={setEnabled}
        aria-label={t("glassCards.label")}
      />
    </span>
  )
}
