import SwiftUI

// MARK: - Service card

/// Something the platform can do, with its price and window stated up front.
struct ServiceCardView: View {
    let offer: ServiceOffer
    var onStart: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: offer.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 42, height: 42)
                    .background(Theme.brandTint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.name)
                        .font(Theme.font(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(offer.summary)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch offer.availability {
            case .available:
                HStack(alignment: .top, spacing: 10) {
                    FigureCell(label: tr("Arrives", "الوصول"), value: offer.window)
                    FigureCell(label: tr("From", "ابتداءً من"), value: "\(offer.currency) \(offer.priceFrom)")
                }
                if let onStart {
                    PrimaryButton(title: tr("Continue", "متابعة"), action: onStart)
                }
            case .notAtThisAirport(let reason), .notForThisFlight(let reason):
                // What the assistant says when a deployment does not sell a
                // service is a designed state, not a dead end.
                Text(reason)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                StatusPill(text: tr("Not available", "غير متاحة"), symbol: "xmark.circle.fill", tone: .changed)
            }
        }
        .cardSurface()
    }
}

// MARK: - Confirmation card

/// The trust gate before anything irreversible.
///
/// Three rules make it work. The button states the full consequence rather
/// than saying "Confirm". The reversibility terms sit *above* the button,
/// where they inform the decision rather than excuse it. And the OTP is
/// announced before it arrives, so the code does not look like phishing.
struct ConfirmationCardView: View {
    let draft: ServiceDraft
    var onConfirm: (() -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Confirm before we book", "أكّد قبل الحجز"))
                .font(Theme.font(.title2, weight: .bold))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 0) {
                summaryRow(tr("Service", "الخدمة"), draft.offer.name)
                summaryRow(draft.offer.quantityLabel.map { $0.capitalized } ?? tr("Quantity", "الكمية"), "\(draft.quantity)")
                summaryRow(tr("Collect", "الاستلام"), "LHR · \(tr("on arrival", "عند الوصول"))")
                summaryRow(tr("Deliver to", "التوصيل إلى"), "\(draft.deliveryAddress), \(draft.deliveryCity)")
                summaryRow(tr("Window", "الفترة"), draft.offer.window)
                summaryRow(tr("Total", "الإجمالي"), draft.totalLabel, isTotal: true)
            }

            Text(draft.reversibility)
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            if let onConfirm {
                // The label carries the whole consequence, including the amount.
                PrimaryButton(title: tr("Confirm and pay \(draft.totalLabel)", "أكّد وادفع \(draft.totalLabel)"),
                              symbol: "lock.fill", action: onConfirm)
            }
            if let onBack {
                SecondaryButton(title: tr("Back", "رجوع"), action: onBack)
            }

            Label(tr("We'll send a code to \(draft.maskedPhone) to authorise",
                     "سنرسل رمزاً إلى \(draft.maskedPhone) للتأكيد"),
                  systemImage: "message.badge.filled.fill")
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface(padding: 18)
    }

    /// `LabeledContent` is the platform's own label-and-value row: it handles
    /// the label/value alignment, truncation and VoiceOver pairing that a
    /// hand-built HStack has to reinvent, and it mirrors correctly in Arabic.
    private func summaryRow(_ label: String, _ value: String, isTotal: Bool = false) -> some View {
        VStack(spacing: 0) {
            LabeledContent {
                Text(value)
                    .font(Theme.font(isTotal ? .headline : .subheadline, weight: isTotal ? .bold : .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(label)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.vertical, 9)
            Divider()
        }
    }
}

// MARK: - Alert card

/// Something changed and it affects the plan.
struct AlertCardView: View {
    let alert: ChangeAlert
    var onAccept: (() -> Void)?
    var onOverrule: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("What changed", "ما الذي تغيّر")).kickerStyle()

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(alert.what)
                    .font(Theme.font(.title, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                StatusPill(text: tr("Changed", "تغيّرت"), symbol: "arrow.triangle.swap", tone: .changed)
            }

            Text("\(alert.from) · \(tr("\(alert.minutesAgo) min ago", "قبل \(alert.minutesAgo) دقائق"))")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink3)

            // The personal consequence, before the fix. An alert that states a
            // fact and leaves the arithmetic to a stressed passenger has done
            // the easy half of the job.
            Text(alert.consequence).verdictStyle()

            RouteSpine(legs: alert.revisedRoute.legs, activeIndex: 0)

            if let onAccept {
                PrimaryButton(title: alert.acceptLabel, symbol: "arrow.triangle.turn.up.right.diamond.fill", action: onAccept)
            }
            if let onOverrule {
                SecondaryButton(title: alert.overruleLabel, action: onOverrule)
            }

            // The cheapest trust device available.
            Text(alert.provenance)
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
        }
        .cardSurface(padding: 18)
    }
}

// MARK: - Help card

struct HelpCardView: View {
    let topic: HelpTopic
    var onEscalate: (() -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(topic.problem)
                .font(Theme.font(.headline, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("What Fly+ can do", "ما يمكن لـ Fly+ فعله")).kickerStyle()
                ForEach(topic.whatFlyPlusCanDo, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("What needs a person", "ما يحتاج إلى شخص")).kickerStyle()
                Text(topic.whatNeedsAHuman)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onEscalate {
                PrimaryButton(title: topic.escalateLabel, symbol: "phone.fill", action: onEscalate)
            }

            Text(tr("Reference \(topic.reference)", "الرقم المرجعي \(topic.reference)"))
                .font(Theme.font(.caption).monospacedDigit())
                .foregroundStyle(Theme.ink3)
        }
        .cardSurface()
    }
}

// MARK: - Clarification card

/// A guess, stated as a guess, with a one-tap correction. Faster and usually
/// kinder than a blank re-ask.
struct ClarificationCardView: View {
    let clarification: Clarification
    var onChoose: ((String) -> Void)?

    @Environment(\.tr) private var tr

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(tr("Best guess", "أفضل تخمين")).kickerStyle()
            }
            .foregroundStyle(Theme.timeSensitive)

            Text(clarification.interpretation)
                .font(Theme.font(.headline, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(tr("Or did you mean:", "أم تقصد:"))
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink3)

            FlowChips(items: clarification.alternatives) { item in
                onChoose?(item)
            }
        }
        .cardSurface()
    }
}

/// Wrapping chip row. Arabic labels run roughly 30% longer than English, so
/// chips wrap rather than truncate.
struct FlowChips: View {
    let items: [String]
    var onTap: ((String) -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
    }

    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Button {
                onTap?(item)
            } label: {
                Text(item)
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 12)
                    .frame(minHeight: Theme.minimumTarget)
                    .background(Theme.surface2, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Dispatcher

/// Renders any component the assistant is allowed to emit.
///
/// Because this switch is exhaustive over `ResponseComponent`, adding a new
/// kind of answer is a compile-time decision — which is the point of treating
/// the kit as a contract rather than a style guide.
struct ResponseComponentView: View {
    let component: ResponseComponent

    @Environment(JourneyStore.self) private var store

    var body: some View {
        switch component {
        case .flightCard(let flight, let density):
            FlightCardView(flight: flight, density: density)
        case .gateCard(let flight, let walk):
            GateCardView(flight: flight, walkMinutes: walk) {
                store.go(to: .routeOverview(store.activeGateRoute))
            }
        case .journeyStatus:
            JourneyStatusCardView()
        case .navigation(let plan):
            NavigationCardView(plan: plan) { store.go(to: .turnByTurn(plan)) }
        case .multiStop(let plan):
            MultiStopRouteCardView(plan: plan) {
                store.go(to: .multiStop(plan))
            } onRemoveStop: {
                store.go(to: .routeOverview(.toGate))
            }
        case .poi(let place):
            POIRow(place: place) { store.go(to: .routeOverview(.viaPrayerRoom)) }
                .cardSurface()
        case .nearby(let heading, let places):
            NearbyRecommendationView(heading: heading, places: places) { _ in
                store.go(to: .explore)
            }
        case .recommendation(let recommendation):
            RecommendationCardView(recommendation: recommendation) {
                store.go(to: recommendation.destination)
            }
        case .service(let offer):
            ServiceCardView(offer: offer) { store.go(to: .serviceFlow(offer)) }
        case .confirmation(let draft):
            ConfirmationCardView(draft: draft)
        case .alert(let alert):
            AlertCardView(alert: alert) {
                store.acceptRevisedRoute(alert)
            } onOverrule: {
                store.keepOldRoute()
            }
        case .help(let topic):
            HelpCardView(topic: topic)
        case .clarification(let clarification):
            ClarificationCardView(clarification: clarification)
        }
    }
}
