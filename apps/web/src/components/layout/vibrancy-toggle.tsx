import { Switch } from "@workspace/ui/components/switch"
import { GlassWater } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useVibrancy } from "@/components/vibrancy-provider"

export function VibrancyToggle() {
  const { t } = useTranslation()
  const { enabled, supported, setEnabled } = useVibrancy()

  if (!supported) return null

  return (
    <span className="inline-flex items-center gap-2 text-sm">
      <GlassWater className="size-4 text-muted-foreground" aria-hidden />
      <span className="text-muted-foreground">{t("vibrancy.label")}</span>
      <Switch
        checked={enabled}
        onCheckedChange={setEnabled}
        aria-label={t("vibrancy.label")}
      />
    </span>
  )
}
