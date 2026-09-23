import SwiftUI

// MARK: - Service flow
//
// §18: "One important differentiator is the ability to move from assistance to
//  execution … The service flow should feel like a continuation of the passenger
//  journey rather than launching an unrelated product."
//
// §19 gates it: a consequential action is never executed because the assistant
// interpreted a spoken request — it always passes through explicit confirmation.
//
// Shape follows the sibling iOS apps: one sheet, a Step enum, a detent per step.

struct ServiceFlowView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let kind: ServiceKind

    enum Step { case review, confirm, done }
    @State private var step: Step = .review
    @State private var bagCount = 2
    @State private var booking: ServiceBooking?

    private var detent: PresentationDetent {
        switch step {
        case .review:  .height(kind == .baggageDelivery ? 560 : 420)
        case .confirm: .height(430)
        case .done:    .height(440)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case .review:  reviewStep
                    case .confirm: confirmStep
                    case .done:    doneStep
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
            footer
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
        .presentationDetents([detent])
        .presentationDragIndicator(.visible)
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 12) {
            if step == .confirm {
                Button {
                    withAnimation(.snappy) { step = .review }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tenant.palette.ink)
                }
            }
            Text(step == .done ? "Confirmed" : kind.title)
                .font(Type.font(17, .semibold))
                .foregroundStyle(tenant.palette.ink)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Step 1 — review

    @ViewBuilder
    private var reviewStep: some View {
        // The flow opens already knowing the journey — no re-entry of known facts (§10).
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 11) {
                row("Flight", "\((store.flight?.number ?? "")) · \((store.flight?.route ?? "—"))")
                Hairline()
                row("Passenger location", store.map.node(store.context.locationNodeID)?.name ?? "Airside")
                if kind == .baggageDelivery {
                    Hairline()
                    row("Deliver to", store.context.homeAddress)
                }
            }
        }

        if kind == .baggageDelivery {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "How many bags")
                Card(padding: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Checked bags")
                                .font(Type.font(15, .semibold))
                                .foregroundStyle(tenant.palette.ink)
                            Text("Collected at the belt, delivered to your door")
                                .font(Type.font(12))
                                .foregroundStyle(tenant.palette.inkMuted)
                        }
                        Spacer()
                        Stepper(value: $bagCount, in: 1...6) {
                            Text("\(bagCount)")
                                .font(Type.mono(18, .semibold))
                                .foregroundStyle(tenant.palette.ink)
                                .frame(minWidth: 24)
                        }
                        .labelsHidden()
                        Text("\(bagCount)")
                            .font(Type.mono(18, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                            .frame(minWidth: 22)
                    }
                }
            }

            Card(padding: 15) {
                VStack(spacing: 10) {
                    row("Delivery", "Tomorrow, 09:00\u{2013}13:00")
                    Hairline()
                    HStack {
                        Text("Total")
                            .font(Type.font(15, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                        Spacer()
                        Text("SAR \(Self.price(for: bagCount))")
                            .font(Type.mono(18, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                    }
                }
            }
        } else {
            Card(padding: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kind.blurb)
                        .font(Type.font(15))
                        .foregroundStyle(tenant.palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("An agent will meet you before boarding.")
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
            }
        }
    }

    // MARK: Step 2 — explicit confirmation (§19)

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind == .baggageDelivery
                 ? "Send \(bagCount) bag\(bagCount == 1 ? "" : "s") to your address?"
                 : "Confirm \(kind.title.lowercased())?")
                .font(Type.font(21, .semibold))
                .foregroundStyle(tenant.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Card(padding: 15) {
                VStack(spacing: 10) {
                    row("Service", kind.title)
                    Hairline()
                    if kind == .baggageDelivery {
                        row("Bags", "\(bagCount)")
                        Hairline()
                        row("To", store.context.homeAddress)
                        Hairline()
                        row("Charge", "SAR \(Self.price(for: bagCount))")
                    } else {
                        row("Flight", (store.flight?.number ?? ""))
                        Hairline()
                        row("Charge", "SAR 0 \u{2014} included")
                    }
                }
            }

            Text("You'll be charged when your bags are collected. You can cancel free of charge until then.")
                .font(Type.font(13))
                .foregroundStyle(tenant.palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Step 3 — done

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(tenant.palette.success)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind == .baggageDelivery ? "Baggage delivery booked" : "\(kind.title) booked")
                        .font(Type.font(19, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    if let booking {
                        Text("Reference \(booking.reference)")
                            .font(Type.font(13))
                            .foregroundStyle(tenant.palette.inkMuted)
                    }
                }
                Spacer(minLength: 0)
            }

            Card(padding: 15) {
                VStack(spacing: 10) {
                    if let booking { row("What happens", booking.summary) }
                    Hairline()
                    row("Next", "Continue to \(store.destinationName)")
                }
            }

            // The service ends by returning the passenger to their journey,
            // rather than stranding them in a separate product.
            Text("I'll keep tracking your flight. Boarding is in \(TimingEngine.durationPhrase(store.minutesToDeadline)).")
                .font(Type.font(14))
                .foregroundStyle(tenant.palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case .review:
                PrimaryButton(title: "Continue", symbol: "arrow.right") {
                    withAnimation(.snappy) { step = .confirm }
                }
            case .confirm:
                HStack(spacing: 10) {
                    SecondaryButton(title: "Not now") { dismiss() }
                    PrimaryButton(title: "Confirm") {
                        let b = ServiceBooking(
                            kind: kind,
                            reference: Self.reference(),
                            summary: kind == .baggageDelivery
                                ? "\(bagCount) bag\(bagCount == 1 ? "" : "s") to \(store.context.homeAddress)"
                                : kind.blurb,
                            bookedAt: store.now
                        )
                        booking = b
                        store.bookings.append(b)
                        withAnimation(.snappy) { step = .done }
                    }
                }
            case .done:
                PrimaryButton(title: "Back to my journey") { dismiss() }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 20)
    }

    // MARK: Helpers

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
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Tiered, matching the Fly+ bag pricing model — not a flat per-bag rate.
    static func price(for bags: Int) -> Int {
        switch bags {
        case ...1: 120
        case 2: 155
        case 3: 190
        case 4: 220
        case 5: 250
        default: 275
        }
    }

    private static func reference() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let a = String((0..<2).map { _ in letters.randomElement()! })
        return "\(a)\(Int.random(in: 10000...99999))"
    }
}
