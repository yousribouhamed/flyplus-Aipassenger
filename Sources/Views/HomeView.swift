import SwiftUI

// MARK: - Journey Home
//
// §8: "This is the most important screen in the product. Do not design a
//  conventional dashboard with many feature tiles."
//
// Hierarchy is fixed by the brief: Now → Next → Ask → Act.

struct HomeView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(spacing: 16) {
                header

                if let alert = store.alert {
                    AlertBanner(alert: alert)
                }

                journeyCard

                if tenant.has(.explore) { nearbySection }

                Color.clear.frame(height: 168)   // clears the tab bar + Ask bar
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    // MARK: Header

    private var greeting: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimingEngine.displayTimeZone
        let h = cal.component(.hour, from: store.now)
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good evening"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Type.font(26, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                Text(store.mode == .visiting ? store.map.name : store.context.stage.label)
                    .font(Type.font(14))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
            Spacer()
            Wordmark()
        }
        .padding(.bottom, 2)
    }

    // MARK: 1–4. Now, Next, interpretation, primary action

    /// Home's anchor slot. Passenger → journey card. Meeting → the same card with
    /// arrival semantics. Visitor → the assistant, because nothing else applies.
    @ViewBuilder
    private var journeyCard: some View {
        if let flight = store.flight, let budget = store.budget {
            JourneyCard(flight: flight, budget: budget)
        } else {
            VisitorAnchor()
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Type.font(10, .semibold))
                .tracking(0.6)
                .foregroundStyle(tenant.palette.inkMuted)
            Text(value)
                .font(Type.font(15, .semibold))
                .foregroundStyle(tenant.palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Nearby & useful

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Nearby & useful", action: ("See all", {
                store.exploreCategory = nil
                store.selectedTab = .explore
            }))

            Card(padding: 14) {
                VStack(spacing: 0) {
                    let items = Array(store.nearby.prefix(3))
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        POIRow(result: item) {
                            store.route(via: item.poi.id)
                            store.startNavigating()
                        }
                        .padding(.vertical, 9)
                        if index < items.count - 1 { Hairline() }
                    }
                }
            }
        }
    }

}

// MARK: - Service tile

struct ServiceTile: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    let kind: ServiceKind
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tenant.palette.primary)
                Text(kind.title)
                    .font(Type.font(14, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.blurb)
                    .font(Type.font(12))
                    .foregroundStyle(tenant.palette.inkMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 168, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(tenant.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tenant.palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $presented) {
            ServiceFlowView(kind: kind).environment(store)
        }
    }
}

// MARK: - Proactive alert banner (§9)

struct AlertBanner: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    let alert: JourneyAlert

    private var tint: Color {
        switch alert.kind {
        case .boarding: tenant.palette.primary
        case .gateChange: tenant.palette.danger
        case .recommendation: tenant.palette.success
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.kind == .gateChange ? "exclamationmark.triangle.fill" : "bell.badge.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(Type.font(15, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                Text(alert.body)
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Button(alert.actionLabel) {
                        store.routeToGate()
                        store.startNavigating()
                        store.dismissAlert()
                    }
                    .font(Type.font(14, .semibold))
                    .foregroundStyle(tint)

                    Button("Dismiss") { store.dismissAlert() }
                        .font(Type.font(14, .medium))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.28), lineWidth: 1))
    }
}
