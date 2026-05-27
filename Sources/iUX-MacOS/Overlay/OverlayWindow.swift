import AppKit
import SwiftUI

// A floating, borderless, draggable panel for visualizer/widget overlays. Stays
// above other windows, joins every Space, doesn't show in the Dock or Cmd-Tab.
// Position is persisted per-name in UserDefaults. Lifted from Clonk so every app
// gets identical overlay behaviour.
@MainActor
public final class OverlayWindow<Content: View>: NSPanel {
    private let storageKey: String

    public init(
        name: String,
        size: NSSize,
        defaultRect: NSRect? = nil,
        @ViewBuilder content: () -> Content
    ) {
        storageKey = "overlay.\(name).frame"
        let saved = UserDefaults.standard.string(forKey: storageKey).flatMap { NSRectFromString($0) }
        let fallback = defaultRect ?? NSRect(x: 100, y: 100, width: size.width, height: size.height)
        let rect = saved ?? fallback
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow

        let host = NSHostingView(rootView: content())
        host.translatesAutoresizingMaskIntoConstraints = false
        contentView = NSView()
        contentView?.addSubview(host)
        if let cv = contentView {
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                host.topAnchor.constraint(equalTo: cv.topAnchor),
                host.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            ])
        }

        // Save position/size whenever the user drags or resizes the overlay,
        // so it survives an unclean quit — not just an explicit hide.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(frameChanged),
                       name: NSWindow.didMoveNotification, object: self)
        nc.addObserver(self, selector: #selector(frameChanged),
                       name: NSWindow.didResizeNotification, object: self)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func frameChanged() { persist() }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    /// Show the panel without stealing focus from the active app.
    public func show() {
        orderFrontRegardless()
    }

    /// Save the current frame so the panel reopens where the user left it.
    public func persist() {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: storageKey)
    }
}
