import { Switch } from "@workspace/ui/components/switch"
import { Shapes } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"

/**
 * Switch for the web `glass-*` components (independent from the native
 * window material — see `VibrancyToggle`). Disabled where the glass look is
 * vetoed by the platform (Linux/WebKitGTK).
 */
export function GlassCardsToggle() {
  const { t } = useTranslation()
  const { enabled, supported, setEnabled } = useGlassCards()

  return (
    <span
      className="inline-flex items-center gap-2 text-sm"
      title={supported ? t("glassCards.hint") : t("vibrancy.unavailable")}
    >
      <Shapes className="size-4 text-muted-foreground" aria-hidden />
      <span className="text-muted-foreground">{t("glassCards.label")}</span>
      <Switch
        checked={enabled}
        onCheckedChange={setEnabled}
        aria-label={t("glassCards.label")}
        disabled={!supported}
      />
    </span>
  )
}
