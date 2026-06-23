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
    // Optional grouping key. When set, items are split into labelled sections.
    private let groupBy: ((Item) -> String)?
    // Optional per-item icon color. Defaults to `.secondary` when nil.
    private let iconColor: ((Item) -> Color)?
    // Optional per-item loading state. When true, replaces the icon with a spinner.
    private let isLoading: ((Item) -> Bool)?

    private var groupedItems: [(key: String, items: [Item])] {
        guard let groupBy else { return [] }
        let grouped = Dictionary(grouping: items, by: groupBy)
        return grouped.keys.sorted().map { (key: $0, items: grouped[$0] ?? []) }
    }

    // The single source of truth for whether the sidebar is showing — the
    // "toggle logic" centralised here rather than in each app.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(
        title: String,
        items: [Item],
        selection: Binding<Item?>,
        emptyPrompt: String = "Nothing selected",
        subtitle: @escaping (Item) -> String? = { _ in nil },
        groupBy: ((Item) -> String)? = nil,
        iconColor: ((Item) -> Color)? = nil,
        isLoading: ((Item) -> Bool)? = nil,
        @ViewBuilder detail: @escaping (Item) -> Detail,
        @ViewBuilder accessory: @escaping (Item) -> Accessory,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.items = items
        self._selection = selection
        self.emptyPrompt = emptyPrompt
        self.subtitle = subtitle
        self.groupBy = groupBy
        self.iconColor = iconColor
        self.isLoading = isLoading
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
        groupBy: ((Item) -> String)? = nil,
        iconColor: ((Item) -> Color)? = nil,
        isLoading: ((Item) -> Bool)? = nil,
        @ViewBuilder detail: @escaping (Item) -> Detail,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) where Accessory == EmptyView {
        self.init(
            title: title,
            items: items,
            selection: selection,
            emptyPrompt: emptyPrompt,
            subtitle: subtitle,
            groupBy: groupBy,
            iconColor: iconColor,
            isLoading: isLoading,
            detail: detail,
            accessory: { _ in EmptyView() },
            footer: footer
        )
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        let color = iconColor?(item) ?? .secondary
        let loading = isLoading?(item) ?? false
        HStack(spacing: 6) {
            Group {
                if loading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: item.icon)
                        .foregroundStyle(color)
                }
            }
            .frame(width: 18)
            if let sub = subtitle(item), !sub.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(item.title)
            }
            Spacer(minLength: 4)
            accessory(item)
        }
    }

    // Button-backed row. A `List(selection:)` sidebar silently drops selection
    // clicks in an LSUIElement (menu-bar / accessory) app's window: that window
    // isn't key, and List selection only tracks in a key window, so rows never
    // highlight or switch even though ordinary controls in the detail pane keep
    // working. Plain Buttons are NSControls and fire regardless of key state, so
    // each row is a Button that sets `selection` itself. The `List` wrapper is
    // kept only for the sidebar's vibrant material + insets; the selection
    // highlight is drawn here.
    @ViewBuilder
    private func selectableRow(for item: Item) -> some View {
        let isSelected = selection == item
        Button {
            selection = item
        } label: {
            row(for: item)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.18))
                                         : AnyShapeStyle(Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowBackground(Color.clear)
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
        // The sidebar is a plain `List` (no `selection:` binding) whose rows are
        // Buttons — see `selectableRow(for:)`. This is what makes the sidebar
        // clickable inside LSUIElement / menu-bar app windows, where a
        // `List(selection:)` silently ignores clicks.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List {
                if groupBy != nil {
                    ForEach(groupedItems, id: \.key) { group in
                        Section(group.key) {
                            ForEach(group.items) { item in
                                selectableRow(for: item)
                            }
                        }
                    }
                } else {
                    ForEach(items) { item in
                        selectableRow(for: item)
                    }
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
