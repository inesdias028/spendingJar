import SwiftUI

extension Color {
    static let evenTeal = Color(red: 0.122, green: 0.541, blue: 0.541)
    static let evenIndigo = Color(red: 0.294, green: 0.357, blue: 0.839)
    static let evenGold = Color(red: 0.788, green: 0.588, blue: 0.227)

    /// Green when positive, red when negative.
    static func money(_ v: Double) -> Color {
        if v > 0.004 { return .green }
        if v < -0.004 { return .red }
        return .primary
    }
}

/// Emoji in a soft rounded square, at the start of list rows.
struct EmojiBadge: View {
    let emoji: String
    var size: CGFloat = 34

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// A short message that slides in at the top and fades away.
struct Toast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.85), in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// One entry in the activity list.
struct EntryRow: View {
    @Environment(Store.self) private var store
    let entry: Entry

    var body: some View {
        let category = store.category(for: entry)
        HStack(spacing: 12) {
            EmojiBadge(emoji: category.emoji)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(store.title(for: entry))
                        .lineLimit(1)
                    if entry.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(signedEuro(entry.signed))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.income ? Color.green : Color.primary)
        }
    }

    /// The note (if any), the time, and "Income" for money in.
    private var subtitle: String {
        var parts: [String] = []
        if entry.hasNote { parts.append(entry.trimmedNote) }
        parts.append(hhmm(entry.date))
        if entry.income { parts.append("Income") }
        return parts.joined(separator: " · ")
    }
}

/// A thin bar showing a share of a total.
struct ShareBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemFill))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}
