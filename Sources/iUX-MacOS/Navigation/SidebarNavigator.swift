import SwiftUI

/// An entry in the iUX sidebar. Apps declare a `CaseIterable` enum of these —
/// same shape as `SettingsTab`, but for a window's primary navigation rather
/// than a popover's tabs.
public protocol SidebarItem: Identifiable, Hashable {
    /// Text shown in the sidebar row.
    var title: String { get }
    /// SF Symbol shown beside the title.
    var icon: String { get }
}

// The shared shell for window-based iUX apps: a sidebar of `SidebarItem`s beside
// the selected item's detail view. iUX owns the `NavigationSplitView` scaffold,
// the sidebar column width, and the collapse/expand *state* — so every window app
// gets identical sidebar behaviour instead of re-deriving column visibility per
// app. The standard macOS toolbar control (and ⌃⌘S) drive that state; apps can
// also toggle it programmatically via `toggleSidebar()`.
@MainActor
public struct SidebarNavigator<Item: SidebarItem, Detail: View, Footer: View>: View {
    private let title: String
    private let items: [Item]
    @Binding private var selection: Item?
    private let emptyPrompt: String
    private let detail: (Item) -> Detail
    private let footer: Footer

    // The single source of truth for whether the sidebar is showing — the
    // "toggle logic" centralised here rather than in each app.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        emptyPrompt: String = "Nothing selected",
        @ViewBuilder detail: @escaping (Item) -> Detail,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.items = items
        self._selection = selection
        self.emptyPrompt = emptyPrompt
        self.detail = detail
        self.footer = footer()
    }

    public var body: some View {
        // NavigationSplitView two-column pattern: bind the sidebar List to
        // `selection`, and let the detail column render directly off that
        // selection. Earlier this used `.navigationDestination(for:)` inside
        // the sidebar column, which works for click-driven navigation but
        // silently no-ops when something sets `selection` programmatically
        // (e.g. App-arently's AppStage driver seeding `selection` at launch) —
        // the list row highlights but the detail column stays on `emptyPrompt`.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(items, selection: $selection) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: UX.sidebarMinWidth, ideal: UX.sidebarIdealWidth)
            .navigationTitle(title)
            .safeAreaInset(edge: .bottom) { footer }
        } detail: {
            if let item = selection {
                detail(item)
            } else {
                ContentUnavailableView(emptyPrompt, systemImage: "sidebar.left")
            }
        }
    }

    /// Collapse the sidebar if shown, reveal it if hidden. Public so apps (or
    /// menu commands) can drive it programmatically; the native toolbar control
    /// toggles the same state.
    public func toggleSidebar() {
        withAnimation(.snappy) {
            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }
}
