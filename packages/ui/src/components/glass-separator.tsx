import { cn } from "@workspace/ui/lib/utils"
import { Separator as SeparatorPrimitive } from "radix-ui"
import * as React from "react"

const GlassSeparator = React.forwardRef<
  React.ElementRef<typeof SeparatorPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SeparatorPrimitive.Root>
>(
  (
    { className, orientation = "horizontal", decorative = true, ...props },
    ref
  ) => (
    <SeparatorPrimitive.Root
      ref={ref}
      decorative={decorative}
      orientation={orientation}
      className={cn(
        "shrink-0 bg-gradient-to-r from-transparent via-white/20 to-transparent",
        orientation === "horizontal" ? "h-px w-full" : "h-full w-px",
        className
      )}
      {...props}
    />
  )
)
GlassSeparator.displayName = SeparatorPrimitive.Root.displayName

export { GlassSeparator }
