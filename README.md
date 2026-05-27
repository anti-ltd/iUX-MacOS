<div align="center">

<img src="assets/banner.png" alt="iUX">

<br>

<img src="https://raw.githubusercontent.com/opensourcevillain/resources/bc6072cd7f49dc155b47c88e79daa9d49ece9b7e/OpenSourceVillain/Banner.png" alt="Open Source Villain">

<br><br>

<img src="assets/icon.png" width="140" alt="iUX">

# iUX-MacOS

**The shared UX layer for our macOS apps.**

![Platform](https://img.shields.io/badge/macOS%2026%20Tahoe-black?style=flat-square)
![Language](https://img.shields.io/badge/Swift%206.1-orange?style=flat-square&logo=swift)
![SwiftPM](https://img.shields.io/badge/SwiftPM-source--only-blue?style=flat-square)
![Linking](https://img.shields.io/badge/static-linked-brightgreen?style=flat-square)

`settings · menu bar · overlays`

</div>

---

> Design tokens, settings chrome, menu-bar hosting, and overlay windows — the shared UX layer for every macOS app we build.

---

## What it is

iUX-MacOS is a tiny, source-only Swift package. Every app links it and gets the same
settings popover, menu-bar agent and floating overlay windows — so we stop
re-coding widget chrome, settings layouts and popover styling app by app.

The components, spacing and styling are lifted straight from **[Clonk](../clonk)**
so apps already built by hand keep matching pixel-for-pixel after migrating.

---

## Source-only

iUX-MacOS ships **no binary** — just Swift source. Apps add it as a local or git
dependency and `import iUX_MacOS`. It static-links and dead-code-strips, so each app's
binary only pays for the pieces it actually uses. Change a design token in one
place and every app that links iUX-MacOS moves together.

---

## What's inside

| Component | Role |
|-----------|------|
| **`UX`** | Design tokens — popover width/padding, card spacing, row padding, dark-glass radius/opacities. The single source of truth for the look. |
| **`SettingsPopover`** | Segmented tab switcher over a fixed-width content column. Supply a `SettingsTab` enum and a per-tab content builder. |
| **`CardSection`** | A titled group of rows. |
| **`ToggleRow`** | Label (+ optional subtitle) and a switch. |
| **`SliderRow`** | Label, slider and read-out; `.percent(…)` for 0–1 sliders. |
| **`PlayButton`** | The circular tinted preview button. |
| **`MenuBarController`** | Installs an `NSStatusItem` — left-click toggles a transient popover, right-click (or Control-click) shows an app-supplied `NSMenu`. Pass `clickStyle: .leftClickMenu` to swap the buttons when the menu is the everyday surface; pass `activatesOnShow: true` when the popover contains text fields that need keyboard focus. |
| **`OverlayWindow<Content>`** | Borderless, draggable, always-on-top panel that joins every Space, stays out of the Dock/Cmd-Tab, and persists its frame per name. |
| **`.glassPanel()`** | The dark-glass chrome (rounded fill + hairline border) for content inside an overlay. |

---

## Install

Add it as a local dependency in an app's `Package.swift`:

```swift
dependencies: [
    .package(path: "../iUX-MacOS"),
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: ["iUX-MacOS"],
        path: "Sources/MyApp"
    ),
]
```

Then `import iUX_MacOS`.

---

## Usage sketch

```swift
import iUX_MacOS
import SwiftUI

enum Tab: String, SettingsTab {
    case general, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String { self == .general ? "slider.horizontal.3" : "info.circle" }
}

struct RootView: View {
    @State private var tab: Tab = .general
    @State private var enabled = true
    @State private var volume = 0.8

    var body: some View {
        SettingsPopover(selection: $tab) { tab in
            switch tab {
            case .general:
                CardSection("Output") {
                    ToggleRow("Enabled", isOn: $enabled)
                    Divider()
                    SliderRow.percent("Volume", value: $volume)
                }
            case .about:
                CardSection { Text("MyApp 1.0") }
            }
        }
    }
}

// In the app delegate:
menuBar = MenuBarController(
    symbolName: "sparkles",
    accessibilityLabel: "MyApp",
    popoverSize: NSSize(width: UX.popoverWidth, height: 400),
    rootView: RootView()
)

// A floating widget overlay:
let overlay = OverlayWindow(name: "widget", size: NSSize(width: 220, height: 90)) {
    Text("hello").padding().glassPanel(padding: 12)
}
overlay.show()
```

---

## How it works

| File | Role |
|------|------|
| [`Tokens.swift`](Sources/iUX-MacOS/Theme/Tokens.swift) | Design tokens — the `UX` namespace of shared metrics |
| [`SettingsPopover.swift`](Sources/iUX-MacOS/Settings/SettingsPopover.swift) | Segmented tab switcher + fixed-width content column |
| [`CardSection.swift`](Sources/iUX-MacOS/Settings/CardSection.swift) | Titled card group of rows |
| [`Rows.swift`](Sources/iUX-MacOS/Settings/Rows.swift) | `ToggleRow`, `SliderRow`, `PlayButton` |
| [`MenuBarController.swift`](Sources/iUX-MacOS/MenuBar/MenuBarController.swift) | `NSStatusItem` host — popover + right-click menu |
| [`OverlayWindow.swift`](Sources/iUX-MacOS/Overlay/OverlayWindow.swift) | Borderless, draggable, always-on-top panel |
| [`GlassPanel.swift`](Sources/iUX-MacOS/Overlay/GlassPanel.swift) | The `.glassPanel()` dark-glass chrome |

---

---

## Privacy

iUX-MacOS is a source-only library. It makes no network connections, collects no analytics, and reads no user data. It has no runtime of its own — it static-links into each app that uses it.

---

## Building

Requires **macOS 26 (Tahoe)** and a recent Swift toolchain.

iUX-MacOS is a library — there's nothing to run on its own. Build and test it with SwiftPM:

```bash
swift build      # compile the library
swift test       # run the tests (if any)
```

Apps consume it via a local path (`../iUX-MacOS`). Check it out as a sibling directory
beside the apps that depend on it:

```
Projects/
├── clonk/        ← an app that links iUX-MacOS
└── iUX-MacOS/    ← this repo
```
