import SwiftUI

// MARK: - Structured assistant response components
//
// §21 lists the minimum set the assistant must be able to trigger: flight,
// gate/journey status, navigation, POI, nearby recommendation, service,
// confirmation, alert and help. Each is a real component here, not prose.

struct AssistantCardView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    let card: AssistantCard

    @State private var servicePresented: ServiceKind?

    var body: some View {
        switch card {
        case .flight:              flightCard
        case .journeyStatus:       statusCard
        case .route(let route):    routeCard(route)
        case .poi(let pois):       poiCard(pois)
        case .nearby(let results): nearbyCard(results)
        case .service(let kind):   serviceCard(kind)
        case .confirmation(let r): confirmationCard(r)
        case .help(let topic):     helpCard(topic)
        }
    }

    // MARK: Flight

    @ViewBuilder
    private var flightCard: some View {
        if let f = store.flight {
            Card(padding: 15) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(f.route)
                        .font(Type.font(20, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    Spacer()
                    StatusPill(status: f.status)
                }
                Hairline()
                HStack(spacing: 0) {
                    cell("Flight", f.number)
                    cell("Gate", f.gate.replacingOccurrences(of: "Gate ", with: ""))
                    cell("Boarding", TimingEngine.clock(f.boarding))
                    cell("Departs", TimingEngine.clock(f.departure))
                }
                }
            }
        }
    }

    // MARK: Journey status

    @ViewBuilder
    private var statusCard: some View {
        if let b = store.budget {
            Card(padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    cell("Boarding in", TimingEngine.durationPhrase(b.minutesToBoarding))
                    cell("Walk to gate", "\(b.walkMinutesToGate) min")
                    cell("Spare", TimingEngine.durationPhrase(max(0, b.availableMinutes)))
                }
                Hairline()
                // The deterministic rule, shown openly — the platform is authoritative.
                Text("Boarding \u{2212} walk \u{2212} \(b.safetyBufferMinutes) min reserve = \(b.availableMinutes) min discretionary")
                    .font(Type.font(12))
                    .foregroundStyle(tenant.palette.inkMuted)
                }
            }
        }
    }

    // MARK: Route

    private func routeCard(_ route: Route) -> some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                AirportMapView(map: store.map, route: route,
                               currentNodeID: store.context.locationNodeID,
                               zone: store.context.zone,
                               showsAllPOIs: false)
                    .frame(height: 168)
                    .clipped()

                VStack(alignment: .leading, spacing: 12) {
                    if let stop = route.stopNodeID, let poi = store.map.poi(stop) {
                        HStack(spacing: 8) {
                            leg("You", nil)
                            arrow("\(route.minutesToStop() ?? 0) min")
                            leg(poi.name, poi.category.symbol)
                            arrow("\(route.minutesFromStop() ?? 0) min")
                            leg(store.destinationName, "airplane.departure")
                        }
                    } else {
                        HStack(spacing: 8) {
                            leg("You", nil)
                            arrow("\(route.minutes) min")
                            leg(route.destination?.name ?? "Gate", "airplane.departure")
                        }
                    }

                    HStack(spacing: 10) {
                        SecondaryButton(title: "Go straight to gate", symbol: "airplane.departure") {
                            store.routeToGate(); store.startNavigating(); store.assistantPresented = false
                        }
                        PrimaryButton(title: "Take me there", symbol: "location.north.line.fill") {
                            store.activeRoute = route
                            store.startNavigating()
                            store.assistantPresented = false
                        }
                    }
                }
                .padding(15)
            }
        }
    }

    private func leg(_ title: String, _ symbol: String?) -> some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            }
            Text(title).font(Type.font(12, .semibold)).lineLimit(1)
        }
        .foregroundStyle(tenant.palette.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tenant.palette.primarySoft)
        .clipShape(Capsule())
    }

    private func arrow(_ label: String) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
            Text(label).font(Type.font(9, .medium))
        }
        .foregroundStyle(tenant.palette.inkMuted)
    }

    // MARK: POI

    private func poiCard(_ pois: [POI]) -> some View {
        Card(padding: 14) {
            VStack(spacing: 0) {
                ForEach(Array(pois.enumerated()), id: \.element.id) { index, poi in
                    HStack(spacing: 12) {
                        Image(systemName: poi.category.symbol)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(tenant.palette.primary)
                            .frame(width: 38, height: 38)
                            .background(tenant.palette.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(poi.name)
                                .font(Type.font(15, .semibold))
                                .foregroundStyle(tenant.palette.ink)
                            Text(poi.detail)
                                .font(Type.font(12))
                                .foregroundStyle(tenant.palette.inkMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Take me there") {
                            store.route(via: poi.id); store.startNavigating(); store.assistantPresented = false
                        }
                        .font(Type.font(13, .semibold))
                        .foregroundStyle(tenant.palette.primary)
                    }
                    .padding(.vertical, 8)
                    if index < pois.count - 1 { Hairline() }
                }
            }
        }
    }

    // MARK: Nearby recommendations

    private func nearbyCard(_ results: [ExploreResult]) -> some View {
        Card(padding: 14) {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, r in
                    POIRow(result: r) {
                        store.route(via: r.poi.id); store.startNavigating(); store.assistantPresented = false
                    }
                    .padding(.vertical, 8)
                    if index < results.count - 1 { Hairline() }
                }
            }
        }
    }

    // MARK: Service

    private func serviceCard(_ kind: ServiceKind) -> some View {
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(tenant.palette.primary)
                        .frame(width: 42, height: 42)
                        .background(tenant.palette.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(Type.font(16, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                        Text(kind.blurb)
                            .font(Type.font(13))
                            .foregroundStyle(tenant.palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                PrimaryButton(title: "Arrange \(kind.title.lowercased())", symbol: "arrow.right") {
                    servicePresented = kind
                }
            }
        }
        .sheet(item: $servicePresented) { kind in
            ServiceFlowView(kind: kind).environment(store)
        }
    }

    // MARK: Confirmation (§19)

    private func confirmationCard(_ request: ConfirmationRequest) -> some View {
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 13) {
                Text(request.title)
                    .font(Type.font(17, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                Text(request.body)
                    .font(Type.font(14))
                    .foregroundStyle(tenant.palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    SecondaryButton(title: request.cancelLabel) { store.pendingConfirmation = nil }
                    PrimaryButton(title: request.confirmLabel) { store.confirm(request) }
                }
            }
        }
    }

    // MARK: Help / escalation (§20)

    private func helpCard(_ topic: String) -> some View {
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: "lifepreserver")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tenant.palette.warning)
                    Text(topic)
                        .font(Type.font(16, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                }
                Text("If this needs a person, I can hand you over to airport staff with your flight and journey details already attached.")
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Talk to a person", symbol: "person.wave.2") {
                    store.pendingConfirmation = ConfirmationRequest(
                        title: "Connect to airport staff?",
                        body: "I'll share \((store.flight?.number ?? "")), \(store.destinationName) and your current location so you don't have to repeat yourself.",
                        confirmLabel: "Connect me", cancelLabel: "Not now",
                        isDestructive: false, service: nil
                    )
                }
            }
        }
    }

    // MARK: Shared

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Type.font(10, .semibold)).tracking(0.6)
                .foregroundStyle(tenant.palette.inkMuted)
            Text(value)
                .font(Type.font(15, .semibold))
                .foregroundStyle(tenant.palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
