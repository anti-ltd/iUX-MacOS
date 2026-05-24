import SwiftUI

// A single labelled metric tile — a caption over a big value with a trailing
// unit, on a soft rounded fill. The unit of a "live readout" row. Lives in iUX
// so every app's stat strips look the same.
public struct StatTile: View {
    let label: String
    let value: String
    let unit: String
    /// Optional per-metric colour. When set, the value is tinted and a small dot
    /// sits beside the label, so a tile reads as the same metric as its chart.
    let accent: Color?

    public init(label: String, value: String, unit: String, accent: Color? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
        self.accent = accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if let accent {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(accent ?? .primary)
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
