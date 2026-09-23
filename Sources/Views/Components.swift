import SwiftUI
import UIKit

// MARK: - Surfaces

struct Card<Content: View>: View {
    @Environment(\.tenant) private var tenant
    var padding: CGFloat = Metric.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tenant.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                    .stroke(tenant.palette.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    @Environment(\.tenant) private var tenant
    let title: String
    var symbol: String?
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(Type.font(16, .semibold))
            .foregroundStyle(tenant.palette.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Metric.controlHeight)
            .background(enabled ? tenant.palette.primary : tenant.palette.inkMuted.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: Metric.controlRadius, style: .continuous))
        }
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    @Environment(\.tenant) private var tenant
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(Type.font(16, .semibold))
            .foregroundStyle(tenant.palette.primary)
            .frame(maxWidth: .infinity)
            .frame(height: Metric.controlHeight)
            .background(tenant.palette.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: Metric.controlRadius, style: .continuous))
        }
    }
}

/// Follow-up / suggested prompt chip.
struct PromptChip: View {
    @Environment(\.tenant) private var tenant
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Type.font(14, .medium))
                .foregroundStyle(tenant.palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(tenant.palette.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(tenant.palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status
//
// §22: "Clear non-color-only status indicators" — every pill carries a glyph.

struct StatusPill: View {
    @Environment(\.tenant) private var tenant
    let status: Flight.Status

    private var tint: Color {
        switch status {
        case .onTime:      tenant.palette.success
        case .boarding:    tenant.palette.primary
        case .delayed:     tenant.palette.warning
        case .gateChanged: tenant.palette.danger
        case .landed:      tenant.palette.success
        }
    }

    private var symbol: String {
        switch status {
        case .onTime: "checkmark.circle.fill"
        case .boarding: "airplane.departure"
        case .delayed: "clock.badge.exclamationmark"
        case .gateChanged: "exclamationmark.triangle.fill"
        case .landed:      "airplane.arrival"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(status.rawValue).font(Type.font(11, .bold)).tracking(0.6)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct MetaPill: View {
    @Environment(\.tenant) private var tenant
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(text).font(Type.font(13, .medium))
        }
        .foregroundStyle(tenant.palette.inkMuted)
    }
}

// MARK: - Text

struct SectionHeader: View {
    @Environment(\.tenant) private var tenant
    let title: String
    var action: (label: String, run: () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Type.font(13, .semibold))
                .tracking(0.8)
                .foregroundStyle(tenant.palette.inkMuted)
                .textCase(.uppercase)
            Spacer()
            if let action {
                Button(action.label, action: action.run)
                    .font(Type.font(13, .semibold))
                    .foregroundStyle(tenant.palette.primary)
            }
        }
    }
}

// MARK: - Brand lockup
//
// Reads entirely from the tenant — this is the only place a wordmark is drawn.

struct Wordmark: View {
    @Environment(\.tenant) private var tenant
    /// Height of the logo mark. The text fallback scales with it.
    var height: CGFloat = 28
    var showsSuffix: Bool = true

    /// A tenant may ship artwork or not; a missing asset must not leave a hole.
    private var artwork: String? {
        guard let name = tenant.logoAsset, UIImage(named: name) != nil else { return nil }
        return name
    }

    var body: some View {
        HStack(spacing: 9) {
            if let artwork {
                Image(artwork)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .accessibilityLabel(tenant.appName)
            } else {
                Text(tenant.wordmark)
                    .font(Type.font(height * 0.54, .bold))
                    .tracking(0.5)
                    .foregroundStyle(tenant.palette.onPrimary)
                    .padding(.horizontal, height * 0.32)
                    .padding(.vertical, height * 0.18)
                    .background(tenant.palette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if showsSuffix, let suffix = tenant.wordmarkSuffix {
                Text(suffix)
                    .font(Type.font(height * 0.5, .medium))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
        }
    }
}

// MARK: - POI row

struct POIRow: View {
    @Environment(\.tenant) private var tenant
    let result: ExploreResult
    var trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tenant.palette.primarySoft)
                    Image(systemName: result.poi.category.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tenant.palette.primary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.poi.name)
                        .font(Type.font(15, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    HStack(spacing: 6) {
                        Text(result.subtitle)
                            .font(Type.font(13))
                            .foregroundStyle(result.feasibility.isOnRoute ? tenant.palette.success : tenant.palette.inkMuted)
                        if !result.feasibility.isFeasible {
                            Text("· Not enough time")
                                .font(Type.font(13, .medium))
                                .foregroundStyle(tenant.palette.warning)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(trailing ?? "\(result.walkMinutes) min")
                    .font(Type.mono(15, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tenant.palette.inkMuted.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Divider

struct Hairline: View {
    @Environment(\.tenant) private var tenant
    var body: some View { Rectangle().fill(tenant.palette.hairline).frame(height: 1) }
}
