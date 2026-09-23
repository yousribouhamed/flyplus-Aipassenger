import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Type scale
//
// Shared across tenants. A tenant may re-brand colour and identity; the
// typographic rhythm is part of the framework, not the branding.

enum Type {
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("InstrumentSans-Regular", size: size).weight(weight)
    }
    /// SF Pro — the system face. Used for display type where the platform's own
    /// voice is wanted; `font(_:_:)` above stays the brand face for everything else.
    static func system(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Tabular figures — countdowns must not jitter as digits change.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom("InstrumentSans-Regular", size: size).weight(weight).monospacedDigit()
    }
}

// MARK: - Layout constants

enum Metric {
    static let gutter: CGFloat        = 20
    static let cardRadius: CGFloat    = 20
    static let controlRadius: CGFloat = 14
    /// "Large touch targets … one-handed use" — §22.
    static let controlHeight: CGFloat = 52
    static let cardPadding: CGFloat   = 18
}

// MARK: - Tenant injection

private struct TenantKey: EnvironmentKey {
    static let defaultValue: Tenant = .flyPlus
}

extension EnvironmentValues {
    var tenant: Tenant {
        get { self[TenantKey.self] }
        set { self[TenantKey.self] = newValue }
    }
}
