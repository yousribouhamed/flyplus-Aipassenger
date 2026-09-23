import SwiftUI

@main
struct PassengerApp: App {
    @State private var store = JourneyStore()

    /// The journey clock ticks so countdowns are live during a demo.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onReceive(clock) { _ in store.tick() }
        }
    }
}
