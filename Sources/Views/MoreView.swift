import SwiftUI

// MARK: - More
//
// §30 of the PDF warns against spending POC effort on large profile/settings
// areas, so this stays thin: the journey, what was booked, help, and the
// deployment switch that proves the white-label claim.

struct MoreView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("More")
                    .font(Type.font(26, .semibold))
                    .foregroundStyle(tenant.palette.ink)

                journeySection
                if !store.bookings.isEmpty { bookingsSection }
                preferencesSection
                deploymentSection
                demoSection

                Color.clear.frame(height: 168)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    // MARK: Journey

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "My journey")
            Card(padding: 15) {
                VStack(spacing: 11) {
                    row("Flight", "\((store.flight?.number ?? "")) · \((store.flight?.airlineName ?? "—"))")
                    Hairline()
                    row("Route", "\((store.flight?.originCity ?? "—")) → \((store.flight?.destinationCity ?? "—"))")
                    Hairline()
                    row("Gate", store.destinationName)
                    Hairline()
                    row("Stage", store.context.stage.label)
                    Hairline()
                    row("Airport", "\(store.map.name) · \(store.map.terminalLabel(for: store.context.zone))")
                }
            }
        }
    }

    // MARK: Bookings

    private var bookingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "My services")
            Card(padding: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(store.bookings.enumerated()), id: \.element.id) { index, b in
                        HStack(spacing: 12) {
                            Image(systemName: b.kind.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(tenant.palette.primary)
                                .frame(width: 38, height: 38)
                                .background(tenant.palette.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.kind.title)
                                    .font(Type.font(15, .semibold))
                                    .foregroundStyle(tenant.palette.ink)
                                Text(b.summary)
                                    .font(Type.font(12))
                                    .foregroundStyle(tenant.palette.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(b.reference)
                                .font(Type.mono(12, .medium))
                                .foregroundStyle(tenant.palette.inkMuted)
                        }
                        .padding(.vertical, 8)
                        if index < store.bookings.count - 1 { Hairline() }
                    }
                }
            }
        }
    }

    // MARK: Preferences

    private var preferencesSection: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Preferences")
            Card(padding: 15) {
                VStack(spacing: 13) {
                    // §22: Arabic/RTL readiness is a design constraint from day one.
                    HStack {
                        Text("Language")
                            .font(Type.font(15, .medium))
                            .foregroundStyle(tenant.palette.ink)
                        Spacer()
                        Text("English")
                            .font(Type.font(14))
                            .foregroundStyle(tenant.palette.inkMuted)
                        Text("· العربية soon")
                            .font(Type.font(13))
                            .foregroundStyle(tenant.palette.inkMuted.opacity(0.7))
                    }
                    Hairline()
                    Toggle(isOn: $store.accessibleRouteOnly) {
                        Text("Prefer step-free routes")
                            .font(Type.font(15, .medium))
                            .foregroundStyle(tenant.palette.ink)
                    }
                    .tint(tenant.palette.primary)
                }
            }
        }
    }

    // MARK: Deployment — the white-label proof
    //
    // "For at least one key screen (preferably Home), demonstrate two branded
    //  versions using the same component structure." Switching here re-themes the
    //  whole app, changes the assistant's identity and the service catalogue, and
    //  turns capabilities on and off — without a single view being swapped.

    private var deploymentSection: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Deployment")
            Card(padding: 15) {
                VStack(alignment: .leading, spacing: 13) {
                    Text("One passenger experience framework, multiple branded deployments. The screens below are identical components — only configuration changes.")
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Tenant.all) { candidate in
                        Button {
                            withAnimation(.snappy) { store.tenant = candidate }
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(candidate.palette.primary)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(String(candidate.wordmark.prefix(1)))
                                            .font(Type.font(13, .bold))
                                            .foregroundStyle(candidate.palette.onPrimary)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.appName)
                                        .font(Type.font(15, .semibold))
                                        .foregroundStyle(tenant.palette.ink)
                                    Text("\(candidate.assistantName) · \(candidate.serviceCatalogue.count) services")
                                        .font(Type.font(12))
                                        .foregroundStyle(tenant.palette.inkMuted)
                                }
                                Spacer()
                                Image(systemName: store.tenant.id == candidate.id ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(store.tenant.id == candidate.id ? tenant.palette.primary : tenant.palette.hairline)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Demo controls
    //
    // The POC has no live AODB or indoor positioning, so the events the brief
    // asks the UX to handle are triggered here rather than waited for.

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Demo controls")
            Card(padding: 15) {
                VStack(spacing: 11) {
                    demoRow("Skip forward 15 minutes", "clock.arrow.circlepath") {
                        store.advance(minutes: 15)
                    }
                    Hairline()
                    demoRow("Simulate gate change", "exclamationmark.triangle") {
                        store.simulateGateChange()
                        store.selectedTab = .home
                    }
                    Hairline()
                    demoRow("Reset conversation", "arrow.counterclockwise") {
                        store.clearConversation()
                    }
                }
            }
        }
    }

    private func demoRow(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tenant.palette.primary)
                    .frame(width: 22)
                Text(title)
                    .font(Type.font(15, .medium))
                    .foregroundStyle(tenant.palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tenant.palette.inkMuted.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Type.font(14))
                .foregroundStyle(tenant.palette.inkMuted)
            Spacer(minLength: 12)
            Text(value)
                .font(Type.font(14, .semibold))
                .foregroundStyle(tenant.palette.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}
