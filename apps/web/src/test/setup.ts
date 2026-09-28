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

// Vitest 5 defines window.localStorage as a getter-only accessor, so plain
// assignment throws — define an own property instead when native storage is
// missing or unusable.
function storageUsable(s: Storage | null | undefined): boolean {
  if (s == null) return false
  try {
    s.setItem("__probe", "1")
    s.removeItem("__probe")
    return true
  } catch {
    return false
  }
}

let nativeStore: Storage | null = null
try {
  nativeStore = window.localStorage
} catch {
  nativeStore = null
}
if (!storageUsable(nativeStore)) {
  // NB: in Vitest 5 globalThis IS the jsdom window and localStorage is a
  // getter-only accessor there, so plain assignment throws — defineProperty
  // creates an own property that shadows it instead.
  for (const target of [window, globalThis]) {
    Object.defineProperty(target, "localStorage", {
      value: localStorageMock,
      configurable: true,
      writable: true,
    })
  }
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
