import SwiftUI

// Design tokens — the single source of truth for iUX's look.
//
// Centralising these numbers is the whole point of iUX: change a radius or a
// glass opacity here once and every app that links iUX moves together. The
// values are lifted straight from Clonk's popover and overlay chrome so apps
// already styled by hand keep matching pixel-for-pixel.
public enum UX {
    // MARK: Settings / popover layout

    /// Fixed width of the settings popover. Clonk's whole UI lives at 460pt.
    public static let popoverWidth: CGFloat = 460
    /// Outer padding around popover content.
    public static let popoverPadding: CGFloat = 16
    /// Gap between the tab picker and the content beneath it.
    public static let tabBarSpacing: CGFloat = 12
    /// Vertical gap between stacked `CardSection`s.
    public static let cardSpacing: CGFloat = 14
    /// Vertical padding inside a settings row (toggles, sliders).
    public static let rowVPadding: CGFloat = 10

    // MARK: Sidebar (window-based apps)

    /// Minimum width of the navigation sidebar before the split view clamps.
    public static let sidebarMinWidth: CGFloat = 200
    /// Preferred resting width of the navigation sidebar.
    public static let sidebarIdealWidth: CGFloat = 220

    // MARK: Floating overlay panels ("dark glass")

    /// Corner radius for floating overlay panels.
    public static let panelCornerRadius: CGFloat = 14
    /// Fill opacity of the dark glass backing.
    public static let panelFillOpacity: Double = 0.55
    /// Opacity of the hairline border around a panel.
    public static let panelBorderOpacity: Double = 0.15
}
