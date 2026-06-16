import AppKit
import SwiftUI

// The menu-bar agent host, generalised from Clonk's AppDelegate. Installs an
// NSStatusItem whose left-click toggles a transient popover and whose right-
// click (or Control-click) shows an app-supplied NSMenu. Apps keep one of these
// alive for the process lifetime — typically a property on their app delegate.
@MainActor
public final class MenuBarController: NSObject {
    /// Which mouse button opens the popover vs the menu. Clonk's pattern (the
    /// default) is left → popover, right → menu — appropriate when the popover
    /// *is* the app. FileDen flips it: the left-click menu is the everyday
    /// surface (New Den, Recents, …) and settings sit one right-click away.
    public enum ClickStyle: Sendable {
        /// Left-click toggles the popover, right-click (or Control-click) shows the menu. Default.
        case leftClickPopover
        /// Left-click shows the menu, right-click (or Control-click) toggles the popover.
        case leftClickMenu
    }

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let menuProvider: (@MainActor () -> NSMenu?)?
    private let clickStyle: ClickStyle
    private let activatesOnShow: Bool

    /// - Parameters:
    ///   - symbolName: SF Symbol for the status-bar button.
    ///   - accessibilityLabel: VoiceOver description for the button.
    ///   - popoverSize: Initial content size (SwiftUI may resize height).
    ///   - rootView: The popover's SwiftUI content (usually a `SettingsPopover`).
    ///   - clickStyle: Which click opens the popover vs the menu. See `ClickStyle`.
    ///   - activatesOnShow: When `true`, activate the app and key the popover's
    ///     window whenever the popover opens. Needed when the popover contains
    ///     text fields or any control that should accept typing immediately;
    ///     status-item (accessory) apps don't activate by default, so without
    ///     this the field stays unfocused.
    ///   - menuProvider: Optional menu. Return `nil` to make the menu click
    ///     fall back to toggling the popover. Rebuilt on every click, so it
    ///     can reflect live state.
    public init(
        symbolName: String,
        accessibilityLabel: String,
        popoverSize: NSSize,
        rootView: some View,
        clickStyle: ClickStyle = .leftClickPopover,
        activatesOnShow: Bool = false,
        menuProvider: (@MainActor () -> NSMenu?)? = nil
    ) {
        self.menuProvider = menuProvider
        self.clickStyle = clickStyle
        self.activatesOnShow = activatesOnShow
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = popoverSize
        popover.contentViewController = NSHostingController(rootView: rootView)
        installStatusItem(symbolName: symbolName, accessibilityLabel: accessibilityLabel)
    }

    /// Whether the popover is currently visible.
    public var isShown: Bool { popover.isShown }

    /// Exposes the installed status item for host-app health checks (e.g. Tahoe
    /// menu bar allow-list guidance). Do not retain outside the controller.
    public func statusItemForGuidance() -> NSStatusItem? { statusItem }

    private func installStatusItem(symbolName: String, accessibilityLabel: String) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Persist the user's chosen position across launches (and keep it out from
        // under the notch once placed).
        item.autosaveName = accessibilityLabel
        if let button = item.button {
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
            button.image = image
            // Fallback so the item is never a zero-width (invisible) button if the
            // SF Symbol fails to resolve on this OS.
            if image == nil { button.title = String(accessibilityLabel.prefix(2)) }
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp ||
            (event?.modifierFlags.contains(.control) ?? false)
        // Map (primary/secondary) × (clickStyle) → menu vs. popover.
        let wantsMenu: Bool
        switch clickStyle {
        case .leftClickPopover: wantsMenu = isSecondary
        case .leftClickMenu:    wantsMenu = !isSecondary
        }
        if wantsMenu, let menu = menuProvider?() {
            // Attach the menu just for this click, then detach so the other
            // button keeps toggling the popover instead of opening the menu.
            statusItem?.menu = menu
            sender.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggle(from: sender)
        }
    }

    /// Toggle the popover. Pass a button to anchor to, or rely on the status item.
    public func toggle(from button: NSStatusBarButton? = nil) {
        guard let anchor = button ?? statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            // For agent apps with text fields in the popover, we need to bring
            // the app forward — accessory apps don't activate on a status click,
            // so without this the field never gets keyboard focus.
            if activatesOnShow { NSApp.activate() }
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
