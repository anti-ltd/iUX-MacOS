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
            // The popover that hosts this button dismisses on click, and the
            // dismissal grabs first-responder back. Without an explicit
            // `makeKeyAndOrderFront`, the new window comes up *visible* but
            // not key — the toolbar still hit-tests (it's an NSControl that
            // works in non-key windows) but the sidebar `List` won't track
            // hover or accept clicks until the user clicks the titlebar.
            // Async lets `openWindow` finish creating the NSWindow first.
            let id = windowID
            DispatchQueue.main.async {
                for window in NSApp.windows {
                    guard let raw = window.identifier?.rawValue, raw.contains(id) else { continue }
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
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
///
/// Selection lives at the call site (`@State private var selection: Tab? =
/// .firstTab`) rather than inside this struct. An earlier draft hoisted the
/// `@State` in here and the resulting `NavigationSplitView` rendered sidebar
/// rows but dropped clicks. Mirroring the working `SidebarNavigator` callers
/// (anti-manager, bundler, app-arently) by taking a `Binding` side-steps the
/// inferred-tag-vs-Binding mismatches that hit generic wrappers.
///
/// The `NavigationSplitView` is built inline here (not via `SidebarNavigator`)
/// because tag/selection inference through two layers of generic wrapper plus
/// `RandomAccessCollection`-laundered cases collapses into a state where
/// `List(selection:)` no longer matches its row tags. Constructing
/// `NavigationSplitView` + `List` + `ForEach` directly with the concrete
/// `Tab` in scope keeps the tag type aligned with the selection binding.
@MainActor
public struct SettingsWindow<Tab: SettingsTab, Content: View>: View
where Tab.AllCases: RandomAccessCollection {
    private let title: String
    private let items: [Tab]
    private let content: (Tab) -> Content
    @Binding private var selection: Tab?
    // Mirrors `SidebarNavigator`'s internal state. Owning it here (instead of
    // letting `NavigationSplitView` manage default visibility) is what the
    // collapse-toolbar button toggles, and matching SidebarNavigator's exact
    // shape removes one variable when debugging sidebar interaction issues.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(
        title: String,
        selection: Binding<Tab?>,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) {
        self.title = title
        self._selection = selection
        // Materialise once at init. `Array(Tab.allCases)` re-evaluated inside
        // `body` would hand `ForEach` a fresh array on every redraw — IDs are
        // stable so it isn't strictly wrong, but it adds a moving variable
        // when chasing hit-testing bugs.
        self.items = Array(Tab.allCases)
        self.content = content
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Button rows, not `List(selection:)` — the latter silently drops
            // clicks in LSUIElement (menu-bar) app windows. See SidebarNavigator.
            List {
                ForEach(items) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selection == tab ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                                                           : AnyShapeStyle(Color.clear))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: UX.sidebarMinWidth, ideal: UX.sidebarIdealWidth)
            .navigationTitle(title)
        } detail: {
            if let tab = selection {
                ScrollView {
                    content(tab)
                        .padding(UX.popoverPadding)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(tab.title)
            } else {
                ContentUnavailableView("Nothing selected", systemImage: "sidebar.left")
            }
        }
    }
}
