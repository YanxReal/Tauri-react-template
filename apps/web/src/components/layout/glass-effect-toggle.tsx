import { Switch } from "@workspace/ui/components/switch"
import { GlassWater } from "lucide-react"
import { useTranslation } from "react-i18next"
import { useGlassCards } from "@/components/glass-cards-provider"
import { usePlatform } from "@/components/layout/native-chrome"
import { useVibrancy } from "@/components/vibrancy-provider"

export function GlassEffectToggle() {
  const { t } = useTranslation()
  const { enabled: glassEnabled, setEnabled: setGlass } = useGlassCards()
  const {
    enabled: vibrancyEnabled,
    supported,
    setEnabled: setVibrancy,
  } = useVibrancy()
  const platform = usePlatform()
  const isLinux = platform === "linux"

  // Combinado: si vibrancy está soportado, ambos deben estar ON para considerar activo.
  // Si no está soportado (Linux/browser), solo glass decide.
  // En Linux forzamos OFF (WebKit glitches amarillos) — toggle deshabilitado.
  const enabled = isLinux
    ? false
    : supported
      ? glassEnabled && vibrancyEnabled
      : glassEnabled

  const onCheckedChange = (next: boolean) => {
    if (isLinux) return
    setGlass(next)
    if (supported) setVibrancy(next)
  }

  return (
    <span
      className="inline-flex items-center gap-2 text-sm"
      title={
        isLinux ? "Efecto vidrio no disponible en Linux (WebKit)" : undefined
      }
    >
      <GlassWater className="size-4 text-muted-foreground" aria-hidden />
      <span className="text-muted-foreground">{t("vibrancy.label")}</span>
      <Switch
        checked={enabled}
        onCheckedChange={onCheckedChange}
        aria-label={t("vibrancy.label")}
        disabled={isLinux}
      />
    </span>
  )
}
