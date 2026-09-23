import CoreGraphics
import Foundation

// MARK: - Route

struct RouteLeg: Identifiable, Equatable {
    let id = UUID()
    let from: MapNode
    let to: MapNode
    let metres: Double
    var minutes: Int { AirportMap.minutes(forMetres: metres) }
}

struct TurnInstruction: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let detail: String
    let symbol: String
    /// Distance from the route start at which this instruction applies.
    let atMetres: Double
}

struct Route: Equatable {
    /// Ordered nodes from origin to final destination, including any stop.
    let nodes: [MapNode]
    let legs: [RouteLeg]
    /// Intermediate stop, when this is a multi-stop route (§15).
    let stopNodeID: String?

    var metres: Double { legs.reduce(0) { $0 + $1.metres } }
    var minutes: Int { AirportMap.minutes(forMetres: metres) }
    var destination: MapNode? { nodes.last }

    /// Walking minutes from the start up to the intermediate stop.
    func minutesToStop() -> Int? {
        guard let stopNodeID, let idx = nodes.firstIndex(where: { $0.id == stopNodeID }) else { return nil }
        let m = legs.prefix(idx).reduce(0) { $0 + $1.metres }
        return AirportMap.minutes(forMetres: m)
    }

    /// Walking minutes from the intermediate stop onward to the destination.
    func minutesFromStop() -> Int? {
        guard let stopNodeID, let idx = nodes.firstIndex(where: { $0.id == stopNodeID }) else { return nil }
        let m = legs.dropFirst(idx).reduce(0) { $0 + $1.metres }
        return AirportMap.minutes(forMetres: m)
    }
}

// MARK: - Router
//
// Dijkstra over the authored graph. Swapping this for a production indoor
// routing engine must not change anything above it — the views consume `Route`.

struct RoutingEngine {
    let map: AirportMap
    /// Confines routing to one side of security. A visitor cannot walk airside,
    /// so a router that can is a router that will eventually send them there.
    var zone: Zone? = nil

    private func allowed(_ id: String) -> Bool {
        guard let zone else { return true }
        return map.node(id)?.zone == zone
    }

    private func neighbours(of id: String, stepFreeOnly: Bool) -> [(String, Double)] {
        map.edges.compactMap { e in
            if stepFreeOnly && !e.stepFree { return nil }
            if e.a == id, allowed(e.b) { return (e.b, e.metres) }
            if e.b == id, allowed(e.a) { return (e.a, e.metres) }
            return nil
        }
    }

    /// Shortest path between two nodes.
    func route(from origin: String, to destination: String, stepFreeOnly: Bool = false) -> Route? {
        guard map.node(origin) != nil, map.node(destination) != nil,
              allowed(origin), allowed(destination) else { return nil }

        var dist: [String: Double] = [origin: 0]
        var prev: [String: String] = [:]
        var visited: Set<String> = []
        var frontier: Set<String> = [origin]

        while !frontier.isEmpty {
            // Small graph — a linear scan is clearer than a heap and fast enough.
            guard let current = frontier.min(by: { (dist[$0] ?? .infinity) < (dist[$1] ?? .infinity) })
            else { break }
            frontier.remove(current)
            visited.insert(current)
            if current == destination { break }

            for (next, metres) in neighbours(of: current, stepFreeOnly: stepFreeOnly) where !visited.contains(next) {
                let candidate = (dist[current] ?? .infinity) + metres
                if candidate < (dist[next] ?? .infinity) {
                    dist[next] = candidate
                    prev[next] = current
                    frontier.insert(next)
                }
            }
        }

        guard dist[destination] != nil else { return nil }

        var ids: [String] = [destination]
        while let p = prev[ids.first!] { ids.insert(p, at: 0) }
        guard ids.first == origin else { return nil }

        return Route(nodes: ids.compactMap { map.node($0) },
                     legs: legs(for: ids),
                     stopNodeID: nil)
    }

    /// Multi-stop: origin → stop → destination, kept as one continuous route so
    /// the passenger never loses their final destination (§15).
    func route(from origin: String, via stop: String, to destination: String, stepFreeOnly: Bool = false) -> Route? {
        guard let first = route(from: origin, to: stop, stepFreeOnly: stepFreeOnly),
              let second = route(from: stop, to: destination, stepFreeOnly: stepFreeOnly)
        else { return nil }

        let ids = first.nodes.map(\.id) + second.nodes.dropFirst().map(\.id)
        return Route(nodes: ids.compactMap { map.node($0) },
                     legs: legs(for: ids),
                     stopNodeID: stop)
    }

    private func legs(for ids: [String]) -> [RouteLeg] {
        zip(ids, ids.dropFirst()).compactMap { a, b in
            guard let na = map.node(a), let nb = map.node(b),
                  let e = map.edges.first(where: { ($0.a == a && $0.b == b) || ($0.a == b && $0.b == a) })
            else { return nil }
            return RouteLeg(from: na, to: nb, metres: e.metres)
        }
    }

    /// Walking minutes between two nodes, or nil when unreachable.
    func minutes(from origin: String, to destination: String) -> Int? {
        route(from: origin, to: destination)?.minutes
    }

    // MARK: Turn-by-turn
    //
    // Derived from the geometry of consecutive legs rather than authored per
    // route, so any route the router produces has instructions.
    func instructions(for route: Route) -> [TurnInstruction] {
        guard route.legs.count > 0 else { return [] }
        var out: [TurnInstruction] = []
        var travelled: Double = 0

        for (index, leg) in route.legs.enumerated() {
            let isLast = index == route.legs.count - 1
            let turn: (String, String)

            if index == 0 {
                turn = ("Head towards \(leg.to.name)", "arrow.up")
            } else {
                let prev = route.legs[index - 1]
                turn = (Self.phrase(prev: prev, next: leg), Self.symbol(prev: prev, next: leg))
            }

            out.append(TurnInstruction(
                text: turn.0,
                detail: isLast ? "\(Int(leg.metres)) m · arrive at \(leg.to.name)"
                               : "Continue \(Int(leg.metres)) m",
                symbol: turn.1,
                atMetres: travelled
            ))
            travelled += leg.metres
        }

        if let dest = route.destination {
            out.append(TurnInstruction(text: "Arrive at \(dest.name)",
                                       detail: "You have reached your destination",
                                       symbol: "flag.checkered",
                                       atMetres: travelled))
        }
        return out
    }

    private static func bearing(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        atan2(b.y - a.y, b.x - a.x)
    }

    private static func delta(prev: RouteLeg, next: RouteLeg) -> CGFloat {
        let incoming = bearing(prev.from.point, prev.to.point)
        let outgoing = bearing(next.from.point, next.to.point)
        var d = outgoing - incoming
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    private static func phrase(prev: RouteLeg, next: RouteLeg) -> String {
        let d = delta(prev: prev, next: next)
        let name = next.to.name
        if d < -0.4 { return "Turn left towards \(name)" }     // −y is up on screen
        if d >  0.4 { return "Turn right towards \(name)" }
        return "Continue straight towards \(name)"
    }

    private static func symbol(prev: RouteLeg, next: RouteLeg) -> String {
        let d = delta(prev: prev, next: next)
        if d < -0.4 { return "arrow.turn.up.left" }
        if d >  0.4 { return "arrow.turn.up.right" }
        return "arrow.up"
    }
}
