import AppKit
import SwiftUI

// Pop-out behaviour for settings popovers, modeled on Clonk's. An app supplies
// one tab enum and one `(Tab) -> View` content builder; iUX renders both the
// menu-bar popover (segmented bar + pop-out button) and the standalone window
// (sidebar nav of the same tabs, same per-tab content). Apps don't repeat the
// menu — they declare it once.
//
// Usage:
//   • Menu-bar popover root: `SettingsPopover(selection:, popOutWindowID:, ...)`
//     adds a "macwindow" trailing button that opens the SwiftUI `Window` with
//     the given id and activates the app.
//   • SwiftUI `Window` scene body: `SettingsWindow(title:, initialTab:, ...)`
//     wraps `SidebarNavigator` around the same content builder.

public extension SettingsPopover where Trailing == PopOutButton {
    /// Popover with a built-in pop-out button on the right of the tab bar.
    /// The button calls `openWindow(id: popOutWindowID)` and activates the app
    /// so the new window comes forward. Pair with a SwiftUI `Window` scene that
    /// uses the matching id (and typically renders `SettingsWindow`).
    init(
        selection: Binding<Tab>,
        width: CGFloat = UX.popoverWidth,
        popOutWindowID: String,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) {
        self.init(
            selection: selection,
            width: width,
            trailing: { PopOutButton(windowID: popOutWindowID) },
            content: content
        )
    }
}

/// The standard "open settings in a window" button used in the popover tab bar.
/// Public so apps can drop it into custom trailing layouts; most apps use the
/// `SettingsPopover` convenience init above and never construct one directly.
public struct PopOutButton: View {
    @Environment(\.openWindow) private var openWindow
    let windowID: String

    public init(windowID: String) { self.windowID = windowID }

    public var body: some View {
        Button {
            openWindow(id: windowID)
            // Accessory apps don't bring new windows forward on their own; the
            // app stays inactive and the window opens behind whatever is in
            // front. Activate explicitly so the pop-out feels like a click.
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Image(systemName: "macwindow")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Open in window")
    }
}

/// The sidebar-style settings shell, for embedding inside a SwiftUI `Window`
/// scene. Uses the same `(Tab) -> Content` closure the popover uses, so the
/// per-tab body is written once. A `Window` scene gives `NavigationSplitView`
/// the unified toolbar, transparent titlebar, and vibrant sidebar a manual
/// `NSWindow` can't reproduce — keep it as a SwiftUI `Window`, not an
/// `NSWindow(contentViewController:)`.
@MainActor
public struct SettingsWindow<Tab: SettingsTab, Content: View>: View
where Tab.AllCases: RandomAccessCollection {
    private let title: String
    private let content: (Tab) -> Content
    @State private var selection: Tab?

    public init(
        title: String,
        initialTab: Tab,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) {
        self.title = title
        self.content = content
        self._selection = State(initialValue: initialTab)
    }

    public var body: some View {
        SidebarNavigator(
            title: title,
            items: Array(Tab.allCases),
            selection: $selection
        ) { tab in
            ScrollView {
                content(tab)
                    .padding(UX.popoverPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(tab.title)
        }
    }
}
