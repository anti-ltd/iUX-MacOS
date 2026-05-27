import AppKit
import SwiftUI

/// A tab an app exposes in its settings popover. Apps declare a `CaseIterable`
/// enum conforming to this; iUX renders the segmented switcher from `title`.
///
/// `SettingsTab` refines `SidebarItem` (same shape — title + icon + Identifiable
/// + Hashable) so the same enum drives both the popover's segmented bar and the
/// pop-out window's sidebar without a second protocol. Existing conformers are
/// unaffected: every `SettingsTab` already had to expose `title`, `icon`,
/// `Identifiable`, `Hashable`.
public protocol SettingsTab: SidebarItem, CaseIterable {}

// The settings popover shell — a segmented tab switcher above a fixed-width
// content column, exactly like Clonk's `PopoverView`. Apps supply the tab enum
// and a builder that returns the body for each tab; the chrome stays identical
// across every app.
//
// Pass a `trailing` view to insert a control on the right side of the tab bar
// (e.g. a pop-out button). Omit it and the bar behaves exactly as before.
public struct SettingsPopover<Tab: SettingsTab, Content: View, Trailing: View>: View
where Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    let width: CGFloat
    let content: (Tab) -> Content
    let trailing: Trailing

    /// Original init — no trailing control. Existing callers are unaffected.
    public init(
        selection: Binding<Tab>,
        width: CGFloat = UX.popoverWidth,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) where Trailing == EmptyView {
        self._selection = selection
        self.width = width
        self.content = content
        self.trailing = EmptyView()
    }

    /// Extended init — trailing view appears to the right of the tab picker.
    public init(
        selection: Binding<Tab>,
        width: CGFloat = UX.popoverWidth,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) {
        self._selection = selection
        self.width = width
        self.trailing = trailing()
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Picker("", selection: $selection) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                trailing
            }
            .padding(.bottom, UX.tabBarSpacing)

            content(selection)
        }
        .padding(UX.popoverPadding)
        .frame(width: width)
        .onExitCommand { NSApp.keyWindow?.close() }
    }
}
