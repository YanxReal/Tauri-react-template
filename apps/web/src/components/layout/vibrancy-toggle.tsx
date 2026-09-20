import { Switch } from "@workspace/ui/components/switch"
import { GlassWater } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useVibrancy } from "@/components/vibrancy-provider"

/**
 * Switch for the NATIVE window material (macOS vibrancy / Windows 11 Mica).
 * Hidden where the OS has no material (Linux, mobile, browser dev), so it
 * never shows a switch that can't do anything. Independent from the glass
 * cards (`GlassCardsToggle`).
 */
export function VibrancyToggle() {
  const { t } = useTranslation()
  const { enabled, supported, setEnabled } = useVibrancy()

  if (!supported) return null

  return (
    <span
      className="inline-flex items-center gap-2 text-sm"
      title={t("vibrancy.hint")}
    >
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
