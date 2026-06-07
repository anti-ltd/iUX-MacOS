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
public struct SidebarNavigator<Item: SidebarItem, Detail: View, Footer: View, Accessory: View>: View {
    private let title: String
    private let items: [Item]
    @Binding private var selection: Item?
    private let emptyPrompt: String
    private let detail: (Item) -> Detail
    private let footer: Footer
    // Optional trailing view per row (e.g. a change badge). Defaults to nothing
    // via the `Accessory == EmptyView` convenience initializer below, so
    // existing call sites are unaffected.
    private let accessory: (Item) -> Accessory
    // Optional secondary line under a row's title (e.g. a repo's remote owner).
    // Defaults to `{ _ in nil }`, so rows stay single-line unless an app opts in.
    private let subtitle: (Item) -> String?

    // The single source of truth for whether the sidebar is showing — the
    // "toggle logic" centralised here rather than in each app.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        emptyPrompt: String = "Nothing selected",
        subtitle: @escaping (Item) -> String? = { _ in nil },
        @ViewBuilder detail: @escaping (Item) -> Detail,
        @ViewBuilder accessory: @escaping (Item) -> Accessory,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.items = items
        self._selection = selection
        self.emptyPrompt = emptyPrompt
        self.subtitle = subtitle
        self.detail = detail
        self.accessory = accessory
        self.footer = footer()
    }

    // Convenience initializer for the common case with no per-row accessory, so
    // existing apps keep calling `SidebarNavigator(title:items:selection:detail:footer:)`
    // unchanged.
    public init(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        emptyPrompt: String = "Nothing selected",
        subtitle: @escaping (Item) -> String? = { _ in nil },
        @ViewBuilder detail: @escaping (Item) -> Detail,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) where Accessory == EmptyView {
        self.init(
            title: title,
            items: items,
            selection: selection,
            emptyPrompt: emptyPrompt,
            subtitle: subtitle,
            detail: detail,
            accessory: { _ in EmptyView() },
            footer: footer
        )
    }

    public var body: some View {
        // NavigationSplitView two-column pattern: bind the sidebar List to
        // `selection`, and let the detail column render directly off that
        // selection. Earlier this used `.navigationDestination(for:)` inside
        // the sidebar column, which works for click-driven navigation but
        // silently no-ops when something sets `selection` programmatically
        // (e.g. App-arently's AppStage driver seeding `selection` at launch) —
        // the list row highlights but the detail column stays on `emptyPrompt`.
        //
        // Use the `List(selection:)` + `ForEach` + explicit `.tag(item)` form
        // (not `List(items, selection:)`). The data-driven `List` initializer
        // auto-tags each row with `item.id`, which silently shadows any
        // `.tag(item)` you add inside — so the binding (typed `Item?`) never
        // matches the row tag (`Item.ID`) and clicks become no-ops. This form
        // makes the tag explicit and keeps the tag/selection types aligned.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                ForEach(items) { item in
                    HStack(spacing: 6) {
                        if let sub = subtitle(item), !sub.isEmpty {
                            // Two-line row: icon beside a title + secondary line.
                            Image(systemName: item.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                Text(sub)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label(item.title, systemImage: item.icon)
                        }
                        Spacer(minLength: 4)
                        accessory(item)
                    }
                    .tag(item)
                }
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
