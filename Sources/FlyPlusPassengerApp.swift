import SwiftUI
import CoreText

@main
struct FlyPlusPassengerApp: App {
    @State private var store = JourneyStore()

    init() {
        AppFontRegistry.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environment(store)
                .environment(\.tr, store.translator)
                .environment(\.layoutDirection, store.language.layoutDirection)
                .environment(\.locale, store.language.locale)
                .font(Theme.font(.body))
                .task { store.start() }
        }
    }
}

/// Journey setup is the only screen allowed to ask which flight the passenger
/// is on. Once it knows, the app never asks again — a question that requires
/// the passenger to restate what the system already knows is a bug.
private struct AppEntryView: View {
    @Environment(JourneyStore.self) private var store

    var body: some View {
        if store.hasJourney {
            RootView()
        } else {
            JourneySetupView()
        }
    }
}

private enum AppFontRegistry {
    static func registerFonts() {
        [
            "InstrumentSans-Variable",
            "InstrumentSans-Italic-Variable"
        ].forEach(registerFont)
    }

    private static func registerFont(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
