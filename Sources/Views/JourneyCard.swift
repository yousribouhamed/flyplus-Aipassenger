import SwiftUI

// MARK: - Journey card
//
// §8 of the brief fixes the hierarchy of this card and calls it the most
// important surface in the product:
//
//   1. Current journey    JED → LHR, SV117 · ON TIME
//   2. What matters now   Boarding in 45 min · Gate 32 · 8 min walk
//   3. Interpretation     "You're on schedule."
//   4. Primary action     Guide me
//
// Drawn as a boarding pass — same `TicketShape` as the scan card, torn
// horizontally — so the journey and the thing that starts it belong to one
// visual family. The stub below the tear carries where to go and what to do,
// which is exactly the split a real pass makes.

struct JourneyCard: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    /// Passed in rather than read from the store, so the card cannot be built
    /// for someone who has no flight at all.
    let flight: Flight
    let budget: TimingEngine.Budget

    private var isMeeting: Bool { store.mode == .meeting }

    private var perforation: CGFloat { store.flightCardExpanded ? 0.62 : 0.56 }

    var body: some View {
        VStack(spacing: 0) {
            top
            tear
            stub
        }
        .background(tenant.palette.surface)
        .clipShape(TicketShape(tear: .horizontal, perforation: perforation, corner: Metric.cardRadius))
        .overlay(
            TicketShape(tear: .horizontal, perforation: perforation, corner: Metric.cardRadius)
                .stroke(tenant.palette.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
    }

    // MARK: 1 — Flight identity

    private var top: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tenant.palette.primary)
                    Text(flight.number)
                        .font(Type.system(17, .bold))
                        .foregroundStyle(tenant.palette.ink.opacity(0.72))
                }
                Spacer()
                statusPill
            }

            route
            countdown

            if store.flightCardExpanded { times }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var statusPill: some View {
        let tint: Color = switch flight.status {
        case .onTime: tenant.palette.success
        case .boarding: tenant.palette.primary
        case .delayed: tenant.palette.warning
        case .gateChanged: tenant.palette.danger
        case .landed: tenant.palette.success
        }
        let symbol = switch flight.status {
        case .onTime: "checkmark.circle.fill"
        case .boarding: "airplane.departure"
        case .delayed: "clock.badge.exclamationmark"
        case .gateChanged: "exclamationmark.triangle.fill"
        case .landed: "airplane.arrival"
        }
        let label = switch flight.status {
        case .onTime: "On time"
        case .boarding: "Boarding"
        case .delayed: "Delayed"
        case .gateChanged: "Gate changed"
        case .landed: "Landed"
        }
        return HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
            Text(label).font(Type.font(14, .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(tint.opacity(0.13), in: Capsule())
    }

    /// Origin and destination given equal weight, joined by the flight itself.
    private var route: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(flight.originCode)
                    .font(Type.system(34, .bold))
                    .foregroundStyle(tenant.palette.ink)
                Text(flight.originCity)
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.inkMuted)
            }

            dottedTrack
                .padding(.top, 16)

            VStack(alignment: .trailing, spacing: 1) {
                Text(flight.destinationCode)
                    .font(Type.system(34, .bold))
                    .foregroundStyle(tenant.palette.ink)
                Text(flight.destinationCity)
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
        }
    }

    private var dottedTrack: some View {
        HStack(spacing: 6) {
            dots
            Image(systemName: "airplane")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tenant.palette.inkMuted.opacity(0.75))
            dots
        }
        .frame(maxWidth: .infinity)
    }

    private var dots: some View {
        Line()
            .stroke(tenant.palette.inkMuted.opacity(0.42),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [0.5, 8]))
            .frame(height: 3)
    }

    // MARK: 2 — What matters now

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.deadlineLabel)
                .font(Type.font(14))
                .foregroundStyle(tenant.palette.inkMuted)

            if budget.minutesToBoarding > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(budget.minutesToBoarding)")
                        .font(Type.system(44, .bold))
                        .foregroundStyle(tenant.palette.ink)
                    Text("min")
                        .font(Type.system(22, .bold))
                        .foregroundStyle(tenant.palette.ink)
                }
            } else {
                Text(store.deadlineClock ?? "—")
                    .font(Type.system(40, .bold))
                    .foregroundStyle(tenant.palette.ink)
            }

            // 3 — the platform's read on the passenger's timing, not the flight's.
            HStack(spacing: 7) {
                Image(systemName: budget.isBehindSchedule ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(TimingEngine.scheduleVerdict(budget))
                    .font(Type.font(14, .medium))
            }
            .foregroundStyle(budget.isBehindSchedule ? tenant.palette.warning : tenant.palette.success)
            .padding(.top, 2)
        }
    }

    /// Once boarding has started the countdown already *is* the boarding time,
    /// so repeating it here would spend a row on a fact the passenger just read.
    private var showsBoardingTime: Bool { budget.minutesToBoarding > 0 }

    private var times: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isMeeting {
                timeColumn("Lands", flight.landing.map(TimingEngine.clock) ?? "—")

                Rectangle()
                    .fill(tenant.palette.hairline)
                    .frame(width: 1, height: 30)
                    .padding(.horizontal, 16)

                timeColumn("Out by", store.deadlineClock ?? "—")
            } else {
                if showsBoardingTime {
                    timeColumn("Boarding", TimingEngine.clock(flight.boarding))

                    Rectangle()
                        .fill(tenant.palette.hairline)
                        .frame(width: 1, height: 30)
                        .padding(.horizontal, 16)
                }

                timeColumn("Departure", TimingEngine.clock(flight.departure))
            }

            Spacer(minLength: 8)

            Text("Airport local time")
                .font(Type.font(12))
                .foregroundStyle(tenant.palette.inkMuted)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func timeColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(Type.font(12))
                .foregroundStyle(tenant.palette.inkMuted)
            Text(value)
                .font(Type.system(18, .bold))
                .foregroundStyle(tenant.palette.ink)
        }
    }

    // MARK: Tear

    private var tear: some View {
        Line()
            .stroke(tenant.palette.hairline,
                    style: StrokeStyle(lineWidth: 1.6, dash: [6, 6]))
            .frame(height: 1.6)
            .padding(.horizontal, 18)
    }

    // MARK: Stub — where to go, and the action

    private var stub: some View {
        VStack(spacing: 12) {
            gateRow

            if tenant.has(.navigate) {
                PrimaryButton(title: ctaTitle, symbol: "location.north.fill") {
                    store.routeToGate()
                    store.startNavigating()
                }
            }

            Button {
                withAnimation(.snappy) { store.flightCardExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(store.flightCardExpanded ? "Hide flight details" : "Show flight details")
                        .font(Type.font(14, .medium))
                    Image(systemName: store.flightCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(tenant.palette.inkMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 13)
        .padding(.bottom, 14)
    }

    private var ctaTitle: String {
        if isMeeting { return "Guide me to \(flight.arrivalsExit)" }
        return budget.isBehindSchedule ? "Go to gate now" : "Guide me to gate"
    }

    private var gateRow: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tenant.palette.primary.opacity(0.14))
                Image(systemName: isMeeting ? "figure.walk.arrival" : "airplane.departure")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tenant.palette.primary)
            }
            .frame(width: 40, height: 40)

            // Neither label may wrap — "Gate 32" breaking across two lines reads
            // as two facts instead of one.
            VStack(alignment: .leading, spacing: 1) {
                Text(isMeeting ? flight.arrivalsExit : flight.gate)
                    .font(Type.system(18, .bold))
                    .foregroundStyle(tenant.palette.ink)
                Text(isMeeting ? "Meet them here" : flight.terminal)
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            Rectangle()
                .fill(tenant.palette.hairline)
                .frame(width: 1, height: 34)

            HStack(spacing: 7) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tenant.palette.primary)
                Text("\(store.walkMinutesToGate) min walk")
                    .font(Type.font(14, .medium))
                    .foregroundStyle(tenant.palette.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(tenant.palette.primarySoft.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A single horizontal rule — used for the dotted flight track and the tear.
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}
