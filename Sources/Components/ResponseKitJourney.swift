import SwiftUI

// MARK: - Flight card

/// The journey itself, at two densities: compact for Home, full for
/// "show my flight".
struct FlightCardView: View {
    let flight: Flight
    var density: ResponseComponent.FlightDensity = .compact

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(flight.airline) \(flight.number)")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Spacer(minLength: 8)
                StatusPill(status: flight.status)
            }

            RouteStrip(flight: flight, showsCityNames: density == .full)

            if density == .full {
                Divider()

                // Four bare values in a row: gate, boarding, seat, terminal.
                // Qantas ships exactly this shape under the route.
                HStack(alignment: .top, spacing: 10) {
                    FigureCell(label: tr("Gate", "البوابة"), value: flight.gate)
                    FigureCell(label: tr("Boarding", "الصعود"), value: tr.clock(flight.boardingTime))
                    FigureCell(label: tr("Seat", "المقعد"), value: flight.seat)
                    FigureCell(label: tr("Terminal", "الصالة"), value: flight.terminal)
                }

                // The one sentence a flight tracker cannot write. It is what
                // licenses the passenger to stop checking.
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .padding(.top, 2)
                    Text(tr("Gate numbers can change up to 30 minutes before boarding. We'll tell you if it does.",
                            "قد تتغير البوابة حتى ٣٠ دقيقة قبل الصعود. سنخبرك إن تغيّرت."))
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("\(flight.airline) \(flight.number) · \(tr("Terminal", "صالة")) \(flight.terminal)")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .cardSurface()
    }
}

// MARK: - Gate card

/// The gate as a destination: where it is, how far, how long you have.
struct GateCardView: View {
    let flight: Flight
    let walkMinutes: Int
    var onGuide: () -> Void = {}

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Gate", "البوابة")).kickerStyle()
                    Text(flight.gate).figureStyle(size: 32)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(tr("Boarding", "الصعود")).kickerStyle()
                    Text(tr.clock(flight.boardingTime)).figureStyle(size: 22)
                }
            }
            Text(tr("Concourse \(flight.concourse) · \(walkMinutes) min walk · after security",
                    "الرصيف \(flight.concourse) · \(walkMinutes) دقائق سيراً · بعد التفتيش"))
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: tr("Guide me to Gate \(flight.gate)", "أرشدني إلى البوابة \(flight.gate)"),
                          symbol: "figure.walk", action: onGuide)
        }
        .cardSurface()
    }
}

// MARK: - Journey status card

/// "What matters now" — the one block that changes with every journey state.
struct JourneyStatusCardView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        let snapshot = store.snapshot
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("What matters now", "ما يهم الآن")).kickerStyle()

            Text(snapshot.headline)
                .font(Theme.font(.title, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.detail)
                .font(Theme.font(.callout, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            // The verdict line: a judgement plus a deadline, never a
            // restatement of the numbers above it.
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(snapshot.tone.foreground)
                    .frame(width: 3)
                    .clipShape(Capsule())
                Text(snapshot.verdict).verdictStyle()
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        }
        .cardSurface(padding: 18)
    }
}

// MARK: - Navigation card

/// A route offered or in progress. Must carry destination, walking time,
/// distance, arrival, floor, accessibility and the deadline consequence — plus
/// whether the destination is before or after security, which changes the
/// meaning of a walking time more than the number does.
struct NavigationCardView: View {
    let plan: RoutePlan
    var onStart: (() -> Void)?

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        let arrival = TimingEngine.arrival(leaving: store.now, walkMinutes: plan.totalWalkMinutes)
        let spare = TimingEngine.minutes(from: arrival, to: store.flight.boardingTime)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.destination)
                        .font(Theme.font(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(plan.destinationDetail)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 8)
                StatusPill(text: plan.isAirside ? tr("After security", "بعد التفتيش") : tr("Before security", "قبل التفتيش"),
                           symbol: "checkmark.shield.fill",
                           tone: .neutral)
            }

            HStack(alignment: .top, spacing: 10) {
                FigureCell(label: tr("Walk", "المدة"), value: "\(plan.totalWalkMinutes) min")
                FigureCell(label: tr("Distance", "المسافة"), value: "\(plan.distanceMetres) m")
                FigureCell(label: tr("Arrive", "الوصول"), value: tr.clock(arrival))
                FigureCell(label: tr("Floor", "الطابق"), value: plan.floor)
            }

            if plan.isStepFree {
                // Stated on the default route rather than hidden in settings:
                // for the passengers who need it, this is the first question.
                Label(tr("Step-free the whole way", "المسار كامل بدون درج"), systemImage: "figure.roll")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.onSchedule)
            }

            // Maps tells you how long the walk takes. Only this product knows
            // whether that is good news.
            Text(tr("Boarding in \(TimingEngine.countdown(minutes: store.minutesToBoarding)) — you'll arrive \(spare) min before boarding.",
                    "الصعود خلال \(TimingEngine.countdown(minutes: store.minutesToBoarding)) — ستصل قبل الصعود بـ \(spare) دقيقة."))
                .verdictStyle()

            if let onStart {
                PrimaryButton(title: tr("Start", "ابدأ"), symbol: "location.fill", action: onStart)
            }
        }
        .cardSurface()
    }
}

// MARK: - Multi-stop route card

/// The hero interaction, as one journey rather than two errands.
///
/// The reason people skip the prayer room, the coffee or the pharmacy is not
/// distance — it is the fear of losing track of time somewhere without a
/// departure board. The deadline guard is the sentence that takes that away.
struct MultiStopRouteCardView: View {
    let plan: RoutePlan
    var onStart: (() -> Void)?
    var onRemoveStop: (() -> Void)?

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        let fits = store.slackMinutes >= (plan.totalElapsedMinutes - plan.totalWalkMinutes)
        let warnAt = store.leaveBy

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Two stops on this route", "محطتان على هذا المسار"))
                    .font(Theme.font(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                StatusPill(text: fits ? tr("Fits your time", "يناسب وقتك") : tr("Tight", "الوقت ضيق"),
                           symbol: fits ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                           tone: fits ? .neutral : .timeSensitive)
            }

            RouteSpine(legs: plan.legs, activeIndex: 1) { leg in
                guard leg.kind == .stop else { return nil }
                // The most valuable sentence on the screen.
                return tr("Stay as long as you need — we'll warn you at \(tr.clock(warnAt))",
                          "ابقَ ما شئت — سننبهك عند \(tr.clock(warnAt))")
            }

            Divider()

            HStack {
                Text(tr("Total walking", "إجمالي المشي"))
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
                Spacer()
                Text("\(plan.totalWalkMinutes) min")
                    .font(Theme.font(.subheadline, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }

            if onStart != nil || onRemoveStop != nil {
                VStack(spacing: 8) {
                    if let onStart {
                        PrimaryButton(title: tr("Start", "ابدأ"), symbol: "location.fill", action: onStart)
                    }
                    if let onRemoveStop {
                        SecondaryButton(title: tr("Remove stop", "احذف المحطة"), symbol: "minus.circle", action: onRemoveStop)
                    }
                }
            }
        }
        .cardSurface()
    }
}

// MARK: - POI

/// A single place, framed by route and time rather than by category.
struct POIRow: View {
    let place: PointOfInterest
    var onTap: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: place.category.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 36, height: 36)
                    .background(Theme.brandTint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("\(place.walkMinutes) min")
                    .font(Theme.font(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
            }
            .frame(minHeight: Theme.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
    }

    /// "On your route" and "adds N min" are the only two facts that help
    /// someone decide, and they are exactly what an airport directory cannot
    /// compute.
    private var subtitle: String {
        var parts: [String] = []
        parts.append(place.isOnRoute ? tr("On your route", "على مسارك") : tr("Off your route", "خارج مسارك"))
        if place.detourMinutes > 0 {
            parts.append(tr("adds \(place.detourMinutes) min", "يضيف \(place.detourMinutes) دقائق"))
        }
        if !place.isOpenNow { parts.append(tr("closed now", "مغلق الآن")) }
        return parts.joined(separator: " · ")
    }
}

/// A short ranked set, ordered by time cost — never by alphabet or by rent.
struct NearbyRecommendationView: View {
    let heading: String
    let places: [PointOfInterest]
    var onSelect: ((PointOfInterest) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading).kickerStyle().padding(.bottom, 4)
            ForEach(Array(places.sorted { $0.detourMinutes < $1.detourMinutes }.prefix(4))) { place in
                POIRow(place: place) { onSelect?(place) }
                if place.id != places.last?.id {
                    Divider()
                }
            }
        }
        .cardSurface()
    }
}

// MARK: - Recommendation

/// The one thing the system actually recommends. Exactly one, because a menu
/// of twelve equally weighted options is what the product exists to replace.
struct RecommendationCardView: View {
    let recommendation: Recommendation
    var onAct: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Recommended", "التوصية")).kickerStyle()
            Text(recommendation.headline)
                .font(Theme.font(.title3, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(recommendation.rationale)
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if let onAct {
                PrimaryButton(title: recommendation.actionLabel, symbol: "figure.walk", action: onAct)
            }
        }
        .cardSurface(padding: 18)
    }
}
