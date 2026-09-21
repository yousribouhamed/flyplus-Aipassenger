import SwiftUI

// MARK: - Colour tokens

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Design tokens for the Fly+ passenger companion.
///
/// The research document is strict about colour: three semantic roles carry
/// *state* (neutral on-schedule, amber time-sensitive, red changed or wrong)
/// and the brand accent is reserved for *interactive* elements. If the accent
/// is ever used to signal urgency, every button starts reading as an alarm.
/// State is also never carried by colour alone — every status ships with a
/// word and an SF Symbol, for glare and for colour vision deficiency.
enum Theme {
    /// #207ce1 — Fly+ brand blue. Interactive elements only.
    static let brand      = Color(hex: 0x207CE1)
    static let brandLight = Color(hex: 0x5BA0F0)
    static let brandTint  = Color(hex: 0xE8F0FC)

    /// Ink scale.
    static let ink        = Color(hex: 0x0E1626)
    static let ink2       = Color(hex: 0x59657B)
    static let ink3       = Color(hex: 0x95A0B2)

    /// Surfaces.
    static let surface    = Color.white
    static let surface2   = Color(hex: 0xF1F4F9)
    static let hairline   = Color(hex: 0xE2E7EF)

    /// Semantic state — used for status, never for chrome.
    static let onSchedule = Color(hex: 0x0F6B53)
    static let onScheduleBackground = Color(hex: 0xDCF0E9)
    static let timeSensitive = Color(hex: 0xB87503)
    static let timeSensitiveBackground = Color(hex: 0xFCF0D9)
    static let changed    = Color(hex: 0xAE3527)
    static let changedBackground = Color(hex: 0xFBE5E2)

    static let buttonHeight: CGFloat = 52
    /// Minimum touch target, per the accessibility floor in the research.
    static let minimumTarget: CGFloat = 44

    /// Soft layered background gradient, shared with the rest of the Fly+ family.
    static var canvas: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xF7FAFF), Color(hex: 0xEDF2FA)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("InstrumentSans-Regular", size: pointSize(for: style), relativeTo: style)
            .weight(weight)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("InstrumentSans-Regular", fixedSize: size)
            .weight(weight)
    }

    private static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}

// MARK: - Type roles

extension View {
    /// The verdict line: the one sentence per screen that only a system which
    /// knows this journey could write. A first-class type style, not body copy.
    func verdictStyle() -> some View {
        font(Theme.font(.title3, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Gate, time, countdown and price: the most-read content in the product.
    /// Tabular figures so digits do not jitter as a countdown ticks.
    func figureStyle(size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(Theme.font(size: size, weight: weight).monospacedDigit())
            .foregroundStyle(Theme.ink)
    }

    /// Small uppercase label above a value.
    func kickerStyle() -> some View {
        font(Theme.font(size: 11, weight: .semibold))
            .tracking(0.9)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink3)
    }

    /// Constrains content to a comfortable reading column so the layout stays
    /// readable on iPad and in landscape instead of stretching edge to edge.
    func responsiveContentWidth(_ maxWidth: CGFloat = 640) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
