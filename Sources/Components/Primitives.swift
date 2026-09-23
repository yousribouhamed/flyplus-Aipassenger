import SwiftUI

// MARK: - Status tones

extension FlightStatus.Tone {
    var foreground: Color {
        switch self {
        case .neutral:       Theme.onSchedule
        case .timeSensitive: Theme.timeSensitive
        case .changed:       Theme.changed
        }
    }

    var background: Color {
        switch self {
        case .neutral:       Theme.onScheduleBackground
        case .timeSensitive: Theme.timeSensitiveBackground
        case .changed:       Theme.changedBackground
        }
    }
}

// MARK: - Cards

/// The app's card is a real `GroupBox` with a custom `GroupBoxStyle`, rather
/// than a hand-rolled container. Using the platform control means it inherits
/// Dynamic Type, accessibility grouping and the system's own layout metrics
/// for free, and it keeps the visual language one step from stock iOS.
struct FlyCardStyle: GroupBoxStyle {
    var padding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
            configuration.content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

private struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        GroupBox {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(FlyCardStyle(padding: padding))
    }
}

extension View {
    func cardSurface(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Status

/// Status is never carried by colour alone: every pill is a `Label`, so it
/// always has a word and a symbol, and it reads correctly to VoiceOver.
struct StatusPill: View {
    let text: String
    let symbol: String
    let tone: FlightStatus.Tone

    init(text: String, symbol: String, tone: FlightStatus.Tone) {
        self.text = text
        self.symbol = symbol
        self.tone = tone
    }

    init(status: FlightStatus) {
        self.init(text: status.rawValue, symbol: status.symbol, tone: status.tone)
    }

    var body: some View {
        Label(text, systemImage: symbol)
            .font(Theme.font(size: 12, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tone.background, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The boarding countdown as it appears over navigation: present, because
/// removing it pushes the passenger back to Home to check — but a chip rather
/// than a card, because giving it equal weight would compete with the
/// instruction the screen is open for.
struct DeadlineChip: View {
    let text: String
    var tone: FlightStatus.Tone = .timeSensitive

    var body: some View {
        Label(text, systemImage: "clock.fill")
            .font(Theme.font(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tone.background, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Actions

/// There is one primary action per screen, and the label states what it does.
/// Where an action is irreversible the label states the whole consequence — a
/// passenger glancing at their phone while walking should not be able to spend
/// SAR 250 by tapping a generic word.
///
/// One flat fill, one radius, one height, and nothing else: no gradient, no
/// shadow, no border. The label is the only thing on it to read, which is the
/// point — everything else on the button is chrome competing with the verb.
///
/// Disabled is a quiet tint rather than the platform's grey slab. "Not yet"
/// and "broken" should not look the same to someone waiting to type a flight
/// number, and the height never changes between the two states, so the layout
/// does not shift as the form becomes valid.
struct PrimaryButton: View {
    let title: String
    var symbol: String?
    var role: ButtonRole?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            label
        }
        .buttonStyle(PrimaryButtonStyle(tint: role == .destructive ? Theme.changed : Theme.brand,
                                        isEnabled: isEnabled))
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var label: some View {
        if let symbol {
            Label(title, systemImage: symbol)
        } else {
            Text(title)
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let tint: Color
    let isEnabled: Bool

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.headline, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Color.white : Theme.ink2)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            // The height is a floor rather than a fixed frame, so a long label
            // or a large Dynamic Type setting grows the button instead of
            // clipping the word the passenger needs.
            .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
            .background(isEnabled ? tint : Theme.surface2, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The quiet alternative. Always present next to an assistant recommendation:
/// it is how the passenger disagrees with the AI without arguing with it.
struct SecondaryButton: View {
    let title: String
    var symbol: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Group {
                if let symbol {
                    Label(title, systemImage: symbol)
                } else {
                    Text(title)
                }
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 24)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .tint(role == .destructive ? Theme.changed : Theme.brand)
    }
}

/// A browsing affordance, deliberately the smallest one in the product — a
/// stock bordered button in a capsule shape.
struct ShortcutChip: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Theme.font(size: 13, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .tint(Theme.ink2)
    }
}

// MARK: - Text roles

/// A bare value under a quiet label. Under time pressure, labels are scanned
/// once and values are scanned repeatedly, so the value gets the weight.
struct FigureCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).kickerStyle()
            Text(value)
                .figureStyle(size: 19)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The route strip: JED ——→ LHR with departure and arrival under each code.
struct RouteStrip: View {
    let flight: Flight
    var showsCityNames = false

    @Environment(\.tr) private var tr
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            endpoint(code: flight.origin.code, time: flight.scheduledDeparture, city: flight.origin.city, alignment: .leading)

            VStack(spacing: 3) {
                Image(systemName: "airplane")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                    // Layout mirrors in Arabic, and so does the direction of
                    // travel — but a real-world direction (a "turn left"
                    // arrow, a map) would not. This one is travel, so it flips.
                    .scaleEffect(x: layoutDirection == .rightToLeft ? -1 : 1, y: 1)
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)

            endpoint(code: flight.destination.code, time: flight.scheduledArrival, city: flight.destination.city, alignment: .trailing)
        }
    }

    private func endpoint(code: String, time: Date, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code).figureStyle(size: 24)
            Text(tr.clock(time))
                .font(Theme.font(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.ink2)
            if showsCityNames {
                Text(city)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Route spine

/// The vertical rail used by the multi-stop card and the alert card: a solid
/// active leg, a dashed pending one. The shape follows Rivian's trip planner
/// and Apple Maps' stop list, which both attach the leg time to the segment
/// rather than to a separate summary.
struct RouteSpine: View {
    let legs: [RouteLeg]
    /// Legs from this index onward are drawn as pending.
    var activeIndex: Int = 0
    var footnote: ((RouteLeg) -> String?)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                HStack(alignment: .top, spacing: 12) {
                    rail(for: leg, index: index, isLast: index == legs.count - 1)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(leg.name)
                                .font(Theme.font(.headline, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            if leg.walkMinutes > 0 {
                                Text("\(leg.walkMinutes) min")
                                    .font(Theme.font(.subheadline, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.ink2)
                            }
                        }
                        if !leg.detail.isEmpty {
                            Text(leg.detail)
                                .font(Theme.font(.footnote))
                                .foregroundStyle(Theme.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let footnote = footnote?(leg) {
                            Text(footnote)
                                .font(Theme.font(.footnote, weight: .semibold))
                                .foregroundStyle(Theme.timeSensitive)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, index == legs.count - 1 ? 0 : 14)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func rail(for leg: RouteLeg, index: Int, isLast: Bool) -> some View {
        VStack(spacing: 2) {
            node(for: leg)
            if !isLast {
                if index >= activeIndex {
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                        .foregroundStyle(Theme.hairline)
                        .frame(width: 2)
                        .frame(minHeight: 26)
                } else {
                    Rectangle()
                        .fill(Theme.brand)
                        .frame(width: 2)
                        .frame(minHeight: 26)
                }
            }
        }
        .frame(width: 14)
    }

    @ViewBuilder
    private func node(for leg: RouteLeg) -> some View {
        Group {
            switch leg.kind {
            case .origin:
                Circle().stroke(Theme.brand, lineWidth: 3)
            case .stop:
                Circle().stroke(Theme.timeSensitive, lineWidth: 3)
            case .destination:
                Circle().fill(Theme.ink)
            }
        }
        .frame(width: 11, height: 11)
        .padding(.top, 5)
    }
}
