// swift-tools-version: 6.1
import PackageDescription

// iUX-MacOS — the shared UX layer for our macOS apps.
//
// A tiny, source-only SwiftPM library. Apps add it as a local/git dependency
// and `import iUX_MacOS` to get the same settings popover, menu-bar host and
// floating overlay windows everywhere — no recoding the same widget chrome per
// app. Static-linked and dead-code-stripped, so each app only pays for what it
// uses.
let package = Package(
    name: "iUX-MacOS",
    // macOS 14 is the floor — none of the components use Tahoe-only APIs, and
    // FileDen needs to keep running on 14–25 with FoundationModels weak-linked.
    // Apps that want Tahoe-only behaviour can still pin a higher floor on their
    // own target; the shared layer doesn't need to force it.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "iUX-MacOS", targets: ["iUX-MacOS"]),
    ],
    targets: [
        .target(
            name: "iUX-MacOS",
            path: "Sources/iUX-MacOS"
        ),
    ]
)
