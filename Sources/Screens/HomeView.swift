import SwiftUI

/// 02 — Journey Home.
///
/// The most important screen in the product, and the one most likely to be
/// ruined by good intentions: every stakeholder will want a tile on it. The
/// defence is the hierarchy, fixed here in code — flight, then what matters
/// now, then the verdict, then one action, then the assistant, then the chips.
///
/// Note what is deliberately absent. No weather. No retail carousel. No grid
/// of six services. The chips are the entire concession to browsing, and they
/// are the last thing on the screen rather than the first.
struct HomeView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Adapt: when something has changed, the change outranks
                // everything else on the screen. Only interrupt when the
                // change alters what the passenger should do.
                if store.stage == .changed && !store.acknowledgedGateChange {
                    AlertCardView(alert: .gateChange) {
                        store.acceptRevisedRoute(.gateChange)
                    } onOverrule: {
                        store.keepOldRoute()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                FlightCardView(flight: store.flight, density: .compact)

                JourneyStatusCardView()

                PrimaryButton(title: store.snapshot.primaryLabel, symbol: "figure.walk") {
                    store.go(to: store.snapshot.primaryDestination)
                }

                askCard

                shortcuts
            }
            .padding(20)
            .padding(.bottom, 24)
            .responsiveContentWidth()
            .animation(.smooth(duration: 0.3), value: store.stage)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(tr("Your journey", "رحلتك"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StatusPill(status: store.flight.status)
            }
        }
    }

    /// The assistant's entry point on Home, with a suggested utterance greyed
    /// in. State Farm ships exactly this, and it is the cheapest way to teach
    /// people what they are allowed to say.
    private var askCard: some View {
        Button {
            store.voice = .idle
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.ink, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Ask Fly+", "اسأل Fly+"))
                        .font(Theme.font(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("“\(store.suggestedUtterance)”")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .accessibilityHint(tr("Opens the Fly+ assistant", "يفتح مساعد Fly+"))
    }

    private var shortcuts: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ShortcutChip(title: tr("Nearby", "ما حولي"), symbol: "location.circle") {
                    store.selectedTab = .explore
                }
                ShortcutChip(title: tr("My flight", "رحلتي"), symbol: "airplane") {
                    store.go(to: .flightDetail)
                }
                ShortcutChip(title: tr("Services", "الخدمات"), symbol: "bag") {
                    store.go(to: .serviceFlow(.offer("baggage")))
                }
                ShortcutChip(title: tr("Help", "المساعدة"), symbol: "lifepreserver") {
                    store.go(to: .help(.missedConnection))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}
