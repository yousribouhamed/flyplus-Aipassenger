import SwiftUI

// MARK: - Root
//
// §8 of the PDF: "Home · Navigate · Explore · More. Voice/Ask should remain
//  persistently accessible rather than occupying a navigation tab."
//
// So the Ask bar floats above the tab bar on every tab, and tabs the tenant has
// disabled simply aren't there.

struct RootView: View {
    @Environment(JourneyStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Group {
            if store.hasJourney {
                journey
            } else {
                JourneySetupView()
            }
        }
        .environment(\.tenant, store.tenant)
        .animation(.snappy, value: store.tenant.id)
    }

    private var journey: some View {
        @Bindable var store = store

        return ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .home:     HomeView()
                case .navigate: NavigateView()
                case .explore:  ExploreView()
                case .more:     MoreView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                AskBar()
                TabBar()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $store.assistantPresented) {
            AssistantOverlay()
                .environment(store)
                .environment(\.tenant, store.tenant)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: Binding(
            get: { store.pendingConfirmation.map { IdentifiedConfirmation(request: $0) } },
            set: { if $0 == nil { store.pendingConfirmation = nil } }
        )) { wrapper in
            ConfirmationSheet(request: wrapper.request)
                .environment(store)
                .environment(\.tenant, store.tenant)
                .presentationDetents([.height(330)])
        }
    }
}

// MARK: - Persistent Ask bar

struct AskBar: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    var body: some View {
        if tenant.has(.voice) {
            HStack(spacing: 10) {
                Button {
                    store.assistantPresented = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tenant.palette.primary)
                        Text(tenant.assistantName)
                            .font(Type.font(15, .medium))
                            .foregroundStyle(tenant.palette.inkMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(tenant.palette.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(tenant.palette.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
                }
                .buttonStyle(.plain)

                // The orb, not a microphone glyph: it is the assistant's face
                // everywhere else in the app, and here it also reports state —
                // it starts spinning the moment it's listening.
                Button {
                    store.beginListening()
                } label: {
                    AssistantOrb(state: store.voiceState, size: 44, haloSpread: 1.18)
                        .frame(width: 52, height: 52)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.voiceState == .idle ? "Start speaking" : "Listening")
            }
            .padding(.horizontal, Metric.gutter)
        }
    }
}

// MARK: - Tab bar

struct TabBar: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    private var tabs: [AppTab] {
        AppTab.allCases.filter { tab in
            guard let capability = tab.capability else { return true }
            return tenant.has(capability)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    store.selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .medium))
                        Text(tab.title)
                            .font(Type.font(11, .medium))
                    }
                    .foregroundStyle(store.selectedTab == tab ? tenant.palette.primary : tenant.palette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Hairline() }
    }
}

// MARK: - Confirmation sheet (§19)

struct IdentifiedConfirmation: Identifiable {
    let request: ConfirmationRequest
    var id: String { request.title }
}

struct ConfirmationSheet: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: ConfirmationRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(request.title)
                .font(Type.font(21, .semibold))
                .foregroundStyle(tenant.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(request.body)
                .font(Type.font(15))
                .foregroundStyle(tenant.palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                SecondaryButton(title: request.cancelLabel) {
                    store.pendingConfirmation = nil
                    dismiss()
                }
                PrimaryButton(title: request.confirmLabel) {
                    store.confirm(request)
                    dismiss()
                }
            }
        }
        .padding(Metric.gutter)
        .padding(.top, 10)
        .background(tenant.palette.canvas.ignoresSafeArea())
    }
}
