import "@testing-library/jest-dom/vitest"
import { vi } from "vitest"

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// Ensure localStorage exists globally (jsdom needs url)
const store = new Map<string, string>()
const localStorageMock = {
  getItem: (key: string) => store.get(key) ?? null,
  setItem: (key: string, value: string) => {
    store.set(key, value)
  },
  removeItem: (key: string) => {
    store.delete(key)
  },
  clear: () => store.clear(),
  length: 0,
  key: () => null,
} as unknown as Storage

if (typeof globalThis.localStorage === "undefined") {
  ;(globalThis as unknown as { localStorage: Storage }).localStorage =
    localStorageMock
}
if (typeof window.localStorage === "undefined") {
  ;(window as unknown as { localStorage: Storage }).localStorage =
    localStorageMock
} else {
  ;(globalThis as unknown as { localStorage: Storage }).localStorage =
    window.localStorage
}

vi.mock("react-i18next", async () => {
  const actual =
    await vi.importActual<typeof import("react-i18next")>("react-i18next")
  return {
    ...actual,
    useTranslation: () => ({
      t: (key: string, opts?: Record<string, unknown>) => {
        if (opts?.returnObjects) {
          if (key === "features.items") {
            return [
              {
                title: "HTML5 Semantic",
                description: "Header, nav, main, section, footer",
              },
              { title: "Bilingual ready", description: "i18next + detection" },
              { title: "Modern stack", description: "pnpm + Turborepo + Vite" },
            ]
          }
        }
        if (opts && typeof opts === "object" && "message" in opts) {
          return `${key} ${String(opts.message)}`
        }
        if (opts && typeof opts === "object" && "key" in opts) {
          return `${key} ${String(opts.key)}`
        }
        return key
      },
      i18n: {
        language: "en",
        changeLanguage: vi.fn().mockResolvedValue(undefined),
      },
    }),
  }
})
