import { describe, expect, it } from "vitest"
import { RESIZE_BAND, resizeEdgeAt } from "./native-chrome"

/**
 * Tests de `resizeEdgeAt`, la función que decide si un mousedown launcha un
 * resize de ventana y de que borde.
 *
 * Importa `resizeEdgeAt` para testearlo, pero el hook `useWindowResizeEdges` que
 * la usa sigue siendo el camino real: este archivo protege la CLASIFICACION
 * (que borde corresponde a que posicion), que es donde un `match` mal escrito
 * redimensiona la ventana por el lado equivocado sin que se note en un test de
 * UI. Solo corre en Linux (ver `title-bar.tsx`), pero la funcion es pura y
 * estos tests corren en cualquier plataforma.
 */

// jsdom arranca con 1024x768; fijamos un tamaño conocido para que los bordes
// sean calculables sin depender del entorno.
const W = 1000
const H = 800

function setViewport(width: number, height: number) {
  Object.defineProperty(window, "innerWidth", {
    value: width,
    configurable: true,
    writable: true,
  })
  Object.defineProperty(window, "innerHeight", {
    value: height,
    configurable: true,
    writable: true,
  })
}

describe("resizeEdgeAt", () => {
  it("detects each of the four corners", () => {
    setViewport(W, H)
    const band = RESIZE_BAND
    expect(resizeEdgeAt(0, 0, band)).toBe("NorthWest")
    expect(resizeEdgeAt(W - 1, 0, band)).toBe("NorthEast")
    expect(resizeEdgeAt(0, H - 1, band)).toBe("SouthWest")
    expect(resizeEdgeAt(W - 1, H - 1, band)).toBe("SouthEast")
  })

  it("detects each of the four sides at their midpoints", () => {
    setViewport(W, H)
    const band = RESIZE_BAND
    expect(resizeEdgeAt(W / 2, 0, band)).toBe("North")
    expect(resizeEdgeAt(W / 2, H - 1, band)).toBe("South")
    expect(resizeEdgeAt(0, H / 2, band)).toBe("West")
    expect(resizeEdgeAt(W - 1, H / 2, band)).toBe("East")
  })

  it("returns null away from every border (so clicks are not hijacked)", () => {
    setViewport(W, H)
    const band = RESIZE_BAND
    // dead center — must NOT be treated as a resize edge, or normal clicks
    // inside the page would try to resize the window.
    expect(resizeEdgeAt(W / 2, H / 2, band)).toBeNull()
    // mid-side, more than a band away from any edge
    expect(resizeEdgeAt(W / 2, 100, band)).toBeNull()
    expect(resizeEdgeAt(100, H / 2, band)).toBeNull()
  })

  it("treats the band as inclusive on the top/left and exact on the bottom/right", () => {
    setViewport(W, H)
    const band = RESIZE_BAND
    // top/left use <= (so the coordinate ON the band counts)
    expect(resizeEdgeAt(0, band, band)).toBe("NorthWest")
    expect(resizeEdgeAt(band, 0, band)).toBe("NorthWest")
    // bottom/right use >= against the far edge
    expect(resizeEdgeAt(W - band, H - 1, band)).toBe("SouthEast")
  })

  it("scales with the window size (not a hardcoded pixel box)", () => {
    setViewport(300, 500)
    const band = RESIZE_BAND
    expect(resizeEdgeAt(0, 0, band)).toBe("NorthWest")
    expect(resizeEdgeAt(299, 499, band)).toBe("SouthEast")
    expect(resizeEdgeAt(150, 250, band)).toBeNull()
  })
})
