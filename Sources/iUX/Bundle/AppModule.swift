import SwiftUI

/// Contract every embeddable app module must satisfy.
///
/// Implement this on a `final class` in your `*Core` package. The standalone
/// binary and any bundle host app interact with your module exclusively through
/// this interface — no direct dependency on internal types required.
///
/// Minimal conformance:
/// ```swift
/// @MainActor
/// public final class ClonkModule: AppModule {
///     public static let moduleID    = "ltd.anti.clonk"
///     public static let displayName = "Clonk"
///     public static let symbolName  = "keyboard"
///     public required init() { … }
///     public func start() { … }
///     public var isMuted: Bool { … }
///     public func settingsView() -> AnyView { AnyView(MySettingsView()) }
/// }
/// ```
@MainActor
public protocol AppModule: AnyObject {

    // MARK: Identity — static so bundle hosts can inspect without instantiating

    /// Reverse-DNS identifier, e.g. `"ltd.anti.clonk"`.
    static var moduleID: String { get }
    /// Human-readable name shown in sidebars and title bars.
    static var displayName: String { get }
    /// SF Symbol name used as the sidebar icon.
    static var symbolName: String { get }

    // MARK: Lifecycle

    /// Required so bundle hosts can instantiate modules generically.
    init()

    /// Wire up whatever the module needs (sound engine, key monitor, etc.).
    /// Called once after the host app finishes launching.
    func start()

    // MARK: Status

    /// `true` when the module is currently suppressed (e.g. a sleep rule fired).
    /// Bundle hosts can reflect this in their sidebar or status bar.
    var isMuted: Bool { get }

    // MARK: UI

    /// A self-contained settings view. Drop it into a sidebar detail pane,
    /// a sheet, or anywhere else. The view manages its own state internally.
    func settingsView() -> AnyView
}

public extension AppModule {
    /// Instance-level accessors for when you have `any AppModule` and need the
    /// identity fields without spelling out the concrete type.
    var moduleID:    String { Self.moduleID }
    var displayName: String { Self.displayName }
    var symbolName:  String { Self.symbolName }
}
