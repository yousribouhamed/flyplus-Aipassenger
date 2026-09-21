import Foundation

/// Something the platform can do for the passenger, with its price and window
/// stated up front.
///
/// Services are deliberately *not* a tab. A permanent Services tab turns a
/// journey product into a marketplace: the moment they have a permanent home,
/// someone fills it, ranks it and puts a promotion in it, and the journey stops
/// being the interface. They surface contextually instead — from Home, from
/// Explore, from the assistant and from journey events.
struct ServiceOffer: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let symbol: String
    let priceFrom: Int
    let currency: String
    let window: String
    let availability: Availability
    /// The one question the first step of the flow needs to ask.
    let firstQuestion: String
    let quantityLabel: String?

    enum Availability: Sendable, Hashable {
        case available
        case notAtThisAirport(String)
        case notForThisFlight(String)

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    /// Wider than the Asana brief, per the POC scope document: baggage,
    /// Meet & Assist, porter, chauffeur, lounge, fast track, buggy, transfer
    /// and parking.
    static let catalogue: [ServiceOffer] = [
        .init(id: "baggage", name: "Baggage delivery",
              summary: "Collected at LHR, delivered to your address",
              symbol: "suitcase.rolling.fill", priceFrom: 125, currency: "SAR",
              window: "Tomorrow, 09:00–13:00", availability: .available,
              firstQuestion: "How many bags?", quantityLabel: "bags"),
        .init(id: "meet-assist", name: "Meet & Assist",
              summary: "A host meets you at the aircraft door",
              symbol: "figure.2.arms.open", priceFrom: 180, currency: "SAR",
              window: "On arrival at LHR", availability: .available,
              firstQuestion: "How many passengers?", quantityLabel: "passengers"),
        .init(id: "fast-track", name: "Fast track",
              summary: "Priority lane through passport control",
              symbol: "figure.walk.motion", priceFrom: 90, currency: "SAR",
              window: "On arrival at LHR", availability: .available,
              firstQuestion: "How many passengers?", quantityLabel: "passengers"),
        .init(id: "lounge", name: "Lounge access",
              summary: "Concourse B · quiet zone, showers, food",
              symbol: "sofa.fill", priceFrom: 160, currency: "SAR",
              window: "Now until boarding", availability: .available,
              firstQuestion: "How many guests?", quantityLabel: "guests"),
        .init(id: "buggy", name: "Buggy to the gate",
              summary: "Step-free ride through the concourse",
              symbol: "car.fill", priceFrom: 60, currency: "SAR",
              window: "Within 10 minutes", availability: .available,
              firstQuestion: "How many passengers?", quantityLabel: "passengers"),
        .init(id: "porter", name: "Porter",
              summary: "Someone carries your bags to the gate",
              symbol: "figure.walk.arrival", priceFrom: 70, currency: "SAR",
              window: "Within 15 minutes", availability: .available,
              firstQuestion: "How many bags?", quantityLabel: "bags"),
        .init(id: "chauffeur", name: "Chauffeur",
              summary: "Private car waiting at LHR arrivals",
              symbol: "steeringwheel", priceFrom: 340, currency: "SAR",
              window: "On arrival at LHR", availability: .available,
              firstQuestion: "How many passengers?", quantityLabel: "passengers"),
        .init(id: "transfer", name: "Airport transfer",
              summary: "Shared transfer into central London",
              symbol: "bus.fill", priceFrom: 120, currency: "SAR",
              window: "On arrival at LHR", availability: .available,
              firstQuestion: "How many passengers?", quantityLabel: "passengers"),
        .init(id: "parking", name: "Parking",
              summary: "Not sold for a departure you are already airside for",
              symbol: "parkingsign", priceFrom: 45, currency: "SAR",
              window: "—",
              availability: .notForThisFlight("Parking is booked before you travel. You're already airside for SV117."),
              firstQuestion: "How many days?", quantityLabel: "days")
    ]

    static func offer(_ id: String) -> ServiceOffer {
        catalogue.first { $0.id == id } ?? catalogue[0]
    }
}

/// A service booking in progress. Nothing here is committed until the
/// confirmation screen: the flow states what has *not* happened yet, which is
/// the anti-anxiety device borrowed from good checkout design.
struct ServiceDraft: Sendable, Hashable {
    var offer: ServiceOffer
    var quantity: Int = 1
    var deliveryAddress: String = "14 Kensington Ct"
    var deliveryCity: String = "London W8"
    var maskedPhone: String = "•••• 4417"

    var total: Int { offer.priceFrom * quantity }

    var totalLabel: String { "\(offer.currency) \(total)" }

    /// Reversibility terms sit *above* the button, where they inform the
    /// decision, rather than below it where they only excuse it.
    var reversibility: String {
        "Free to cancel until your bags are collected. After that, 50% is refundable."
    }
}
