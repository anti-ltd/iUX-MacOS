import SwiftUI

// Text and chip inputs — the editable counterparts to Rows.swift's read-mostly
// controls. Kept here so every app gets the same field chrome and the same pill
// styling without re-rolling it per screen.

// MARK: - TextFieldRow

/// A bordered text field with an optional leading label and a trailing accessory
/// (a parse/clear/submit button, say). Set `axis: .vertical` for multi-line copy.
public struct TextFieldRow<Accessory: View>: View {
    let label: String?
    let prompt: String
    @Binding var text: String
    let axis: Axis
    @ViewBuilder let accessory: Accessory
    let onSubmit: (() -> Void)?

    public init(
        _ label: String? = nil,
        prompt: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        onSubmit: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.prompt = prompt
        self._text = text
        self.axis = axis
        self.onSubmit = onSubmit
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let label {
                Text(label).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
            }
            TextField(prompt, text: $text, axis: axis)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSubmit?() }
            accessory
        }
        .padding(.vertical, UX.rowVPadding)
    }
}

public extension TextFieldRow where Accessory == EmptyView {
    init(
        _ label: String? = nil,
        prompt: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        onSubmit: (() -> Void)? = nil
    ) {
        self.init(label, prompt: prompt, text: text, axis: axis, onSubmit: onSubmit) { EmptyView() }
    }
}

// MARK: - Chip

/// The footprint of a `Chip` — `.regular` for standalone pills, `.small` for
/// dense rows of presets or tags.
public enum ChipSize {
    case regular, small

    var font: Font { self == .small ? .caption.weight(.medium) : .callout }
    var hPadding: CGFloat { self == .small ? 10 : 12 }
    var vPadding: CGFloat { self == .small ? 4 : 6 }
}

/// A tappable pill. Tinted when selected, quiet otherwise — the unit of a
/// `ChipGroup`. Use it for quick presets, filters, or any "pick one of these"
/// cluster that should wrap. Pass `onRemove` to make it a removable token (a
/// trailing ✕; tapping anywhere removes it) instead of a toggle.
///
/// `action` is deliberately ahead of `onRemove` so a trailing-closure call site
/// (`Chip("x") { … }`) binds to `action`, not the removal handler — pass
/// `onRemove:` by label when you want a token.
public struct Chip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let size: ChipSize
    let action: () -> Void
    let onRemove: (() -> Void)?

    public init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool = false,
        size: ChipSize = .regular,
        action: @escaping () -> Void = {},
        onRemove: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.size = size
        self.action = action
        self.onRemove = onRemove
    }

    public var body: some View {
        Button(action: onRemove ?? action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                if onRemove != nil {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.7)
                }
            }
            .font(size.font)
            .padding(.horizontal, size.hPadding)
            .padding(.vertical, size.vPadding)
            .background {
                Capsule().fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CircleButton

/// A round icon button. `prominent` fills it with the current tint (for a primary
/// action like play); otherwise it's a quiet tinted glyph on a soft fill. Set the
/// colour with `.tint(_:)` at the call site.
public struct CircleButton: View {
    let systemImage: String
    let prominent: Bool
    let size: CGFloat
    let action: () -> Void

    public init(
        systemImage: String,
        prominent: Bool = false,
        size: CGFloat = 46,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.prominent = prominent
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .background(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Circle())
                .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - ChipGroup

/// A wrapping row of `Chip`s built from a collection. The closures say how to
/// label each item and whether it reads as selected; tapping hands the item back.
public struct ChipGroup<Item: Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    let isSelected: (Item) -> Bool
    let size: ChipSize
    let select: (Item) -> Void

    public init(
        _ items: [Item],
        title: @escaping (Item) -> String,
        isSelected: @escaping (Item) -> Bool = { _ in false },
        size: ChipSize = .regular,
        select: @escaping (Item) -> Void
    ) {
        self.items = items
        self.title = title
        self.isSelected = isSelected
        self.size = size
        self.select = select
    }

    public var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items) { item in
                Chip(title(item), isSelected: isSelected(item), size: size) { select(item) }
            }
        }
    }
}
