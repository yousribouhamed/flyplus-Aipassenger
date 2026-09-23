import SwiftUI

// MARK: - Assistant orb
//
// The visual identity of the voice assistant, and the primary indicator of
// which state it is in (§11: Idle → Listening → Processing → Speaking → Error).
//
// Patterns taken from the current generation of voice assistants (Meta AI,
// ChatGPT, Spotify DJ, Roku, Natural AI, Microsoft Copilot, Pi):
//
//  1. **Annular means receiving; filled means emitting.** Every app that shows a
//     hollow ring does so while *listening*, and switches to a filled or
//     particle-dense form while *speaking*. That mapping is doing real work, so
//     it is kept here rather than inventing a new one.
//  2. **On a light canvas, orbs are soft, not hard-edged.** The dark-background
//     apps can afford a crisp neon ring; the light-background ones (Natural AI,
//     Copilot, Pi) all use blurred, low-contrast gradients. This app is light.
//  3. **Motion carries the state, not colour alone.** Each state below has its
//     own motion signature, so it stays readable for a passenger who cannot
//     distinguish the hues (§22) and at a glance while walking.
//  4. **Cancel is always reachable** during listening — never a trap.
//
// White-label note: nothing here is a fixed "AI gradient". The hues come from
// `tenant.palette.orbTints`, so an airport deployment gets its own orb.

struct AssistantOrb: View {
    @Environment(\.tenant) private var tenant

    let state: VoiceState
    var size: CGFloat = 128
    /// How much room the halo is given. The full bloom needs 1.7×; inline in a
    /// control it has to sit tight or it pushes its neighbours around.
    var haloSpread: CGFloat = 1.7

    // Motion signature per state — the part a passenger reads before the label.
    private var spin: Double {
        switch state {
        case .idle: 0.10          // barely drifting
        case .listening: 0.55
        case .processing: 1.9     // urgent, clearly "working"
        case .speaking: 0.30
        case .failed: 0
        }
    }

    private var breathPeriod: Double {
        switch state {
        case .idle: 3.4
        case .listening: 1.5
        case .processing: 1.0
        case .speaking: 0.62      // speech cadence
        case .failed: 0
        }
    }

    private var breathDepth: CGFloat {
        switch state {
        case .idle: 0.022
        case .listening: 0.055
        case .processing: 0.030
        case .speaking: 0.075
        case .failed: 0
        }
    }

    /// Ring thickness as a fraction of the orb. Listening is thin and open;
    /// speaking closes toward a filled core.
    private var ringFraction: CGFloat {
        switch state {
        case .idle: 0.10
        case .listening: 0.085
        case .processing: 0.11
        case .speaking: 0.46      // reads as filled
        case .failed: 0.09
        }
    }

    private var tints: [Color] {
        state == .failed
            ? [tenant.palette.danger, tenant.palette.danger.opacity(0.5)]
            : tenant.palette.orbTints
    }

    /// Conic stops, wrapped so the gradient meets itself seamlessly.
    private var conic: AngularGradient {
        let c = tints
        return AngularGradient(colors: c + [c.first ?? tenant.palette.primary],
                               center: .center)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: state == .failed)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breath = breathPeriod == 0 ? 0 : sin(t * .pi * 2 / breathPeriod)
            let scale = 1 + breathDepth * CGFloat(breath)
            let angle = Angle(degrees: t * 360 * spin)

            ZStack {
                halo(scale: scale)
                body(angle: angle, t: t)
                    .scaleEffect(scale)
                if state == .processing { comet(angle: angle) }
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.45), value: state)
        }
        .frame(width: size * haloSpread, height: size * haloSpread)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Layers

    /// The atmospheric bloom. Does the heavy lifting on a light background —
    /// without it the orb reads as a flat sticker.
    private func halo(scale: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [tints.first?.opacity(0.34) ?? .clear, .clear],
                    center: .center,
                    startRadius: size * 0.16,
                    endRadius: size * 0.82
                )
            )
            .frame(width: size * 1.62, height: size * 1.62)
            .scaleEffect(scale)
            .blur(radius: size * 0.09)
    }

    private var texture: String? {
        guard let name = tenant.palette.orbTexture, UIImage(named: name) != nil else { return nil }
        return name
    }

    @ViewBuilder
    private func body(angle: Angle, t: Double) -> some View {
        ZStack {
            // Rendered sphere texture, masked to the orb and slowly counter-rotating.
            // Static artwork cannot express five states, so it is the *surface* —
            // the ring, halo and comet above it still carry the state.
            if let texture {
                Image(texture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.94, height: size * 0.94)
                    .clipShape(Circle())
                    .rotationEffect(-angle * 0.45)
                    .opacity(state == .failed ? 0.25 : 0.92)
                    .saturation(state == .processing ? 1.15 : 1.0)
            }

            // Soft outer bloom of the ring itself.
            Circle()
                .strokeBorder(conic, lineWidth: size * ringFraction * 1.9)
                .rotationEffect(angle)
                .blur(radius: size * 0.075)
                .opacity(0.65)

            // The ring proper.
            Circle()
                .strokeBorder(conic, lineWidth: size * ringFraction)
                .rotationEffect(angle)
                .blur(radius: size * 0.012)

            // Speaking fills the middle; listening leaves it open.
            if state == .speaking {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.9), tints.first?.opacity(0.25) ?? .clear],
                            center: UnitPoint(x: 0.42, y: 0.36),
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blur(radius: size * 0.03)
            }

            // Specular highlight — keeps it spherical rather than a flat donut.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(x: -size * 0.17, y: -size * 0.2)
                .blur(radius: size * 0.05)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
    }

    /// A bright short arc that races ahead of the ring — reads unmistakably as
    /// "thinking", and is the one state a passenger should not mistake for input.
    private func comet(angle: Angle) -> some View {
        Circle()
            .trim(from: 0, to: 0.16)
            .stroke(
                LinearGradient(colors: [.clear, tints.last ?? tenant.palette.primary],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round)
            )
            .frame(width: size * 0.97, height: size * 0.97)
            .rotationEffect(angle * 1.7)
            .blur(radius: size * 0.01)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: "Assistant ready"
        case .listening: "Listening"
        case .processing: "Thinking"
        case .speaking: "Speaking"
        case .failed: "Didn't catch that"
        }
    }
}

// MARK: - Orb + its label
//
// The label is deliberately *under* the orb and secondary — the shape and motion
// should already have told the passenger what is happening.

struct AssistantOrbStage: View {
    @Environment(\.tenant) private var tenant
    let state: VoiceState
    var size: CGFloat = 128
    var onCancel: (() -> Void)?

    private var caption: String {
        switch state {
        case .idle: "Tap to speak"
        case .listening: "Listening\u{2026}"
        case .processing: "One moment\u{2026}"
        case .speaking: "Speaking"
        case .failed: "I didn't catch that"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            AssistantOrb(state: state, size: size)

            Text(caption)
                .font(Type.font(16, .semibold))
                .foregroundStyle(state == .failed ? tenant.palette.danger : tenant.palette.ink)
                .contentTransition(.opacity)

            // Always escapable while the mic is open (§11).
            if let onCancel, state == .listening || state == .processing {
                Button("Cancel", action: onCancel)
                    .font(Type.font(15, .medium))
                    .foregroundStyle(tenant.palette.inkMuted)
                    .padding(.top, 6)
            }
        }
    }
}
