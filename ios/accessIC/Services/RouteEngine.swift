import Foundation

struct RouteStep: Equatable, Sendable, Identifiable {
    var id: String { "\(from.id)->\(to.id)" }
    let from: GraphNode
    let to: GraphNode
    let edge: GraphEdge
    let instruction: String
}

struct RouteResult: Equatable, Sendable {
    let nodes: [GraphNode]
    let steps: [RouteStep]
    let totalLengthMeters: Float?
    let usedAccessibleProfile: Bool
    let dataState: GraphDataState

    var isPrototype: Bool { dataState == .uiPrototype }
}

enum RouteEngineError: Error, LocalizedError, Equatable {
    case unknownNode(String)
    case noPath
    case prototypeOnly

    var errorDescription: String? {
        switch self {
        case .unknownNode(let id): return "Unknown graph node: \(id)"
        case .noPath: return "No route found for the selected accessibility profile."
        case .prototypeOnly: return "This graph is a UI prototype. Do not present it as verified Whalen navigation."
        }
    }
}

/// Client-side Dijkstra with explicit accessibility filtering.
struct RouteEngine: Sendable {
    let graph: FloorGraph

    func route(
        from startID: String,
        to goalID: String,
        accessibleMode: Bool
    ) throws -> RouteResult {
        guard graph.node(id: startID) != nil else { throw RouteEngineError.unknownNode(startID) }
        guard graph.node(id: goalID) != nil else { throw RouteEngineError.unknownNode(goalID) }

        var adjacency: [String: [(to: String, edge: GraphEdge, weight: Float)]] = [:]
        for edge in graph.edges {
            guard edge.status != .closed else { continue }
            if accessibleMode {
                // Never treat unknown stair flags as step-free.
                if edge.hasStairs == true { continue }
                if edge.edgeType == .stairs { continue }
                // Unverified edges are usable for prototype UI routing but must be labeled as such by the caller.
            }
            let weight = edge.lengthMeters ?? 1.0
            adjacency[edge.from, default: []].append((edge.to, edge, weight))
            adjacency[edge.to, default: []].append((edge.from, edge, weight))
        }

        var dist: [String: Float] = [startID: 0]
        var prev: [String: (node: String, edge: GraphEdge)] = [:]
        var visited = Set<String>()
        var queue: [String] = graph.nodes.map(\.id)

        while !queue.isEmpty {
            queue.sort { (dist[$0] ?? .infinity) < (dist[$1] ?? .infinity) }
            let u = queue.removeFirst()
            if u == goalID { break }
            if visited.contains(u) { continue }
            visited.insert(u)
            let du = dist[u] ?? .infinity
            for next in adjacency[u] ?? [] {
                let alt = du + next.weight
                if alt < (dist[next.to] ?? .infinity) {
                    dist[next.to] = alt
                    prev[next.to] = (u, next.edge)
                }
            }
        }

        guard dist[goalID] != nil else { throw RouteEngineError.noPath }

        var pathIDs = [goalID]
        var current = goalID
        while current != startID {
            guard let step = prev[current] else { throw RouteEngineError.noPath }
            pathIDs.append(step.node)
            current = step.node
        }
        pathIDs.reverse()

        let nodes = pathIDs.compactMap { graph.node(id: $0) }
        var steps: [RouteStep] = []
        var total: Float = 0
        var hasMeasured = true
        for i in 0..<(nodes.count - 1) {
            let a = nodes[i]
            let b = nodes[i + 1]
            guard let edge = graph.edges.first(where: {
                ($0.from == a.id && $0.to == b.id) || ($0.from == b.id && $0.to == a.id)
            }) else { continue }
            if let len = edge.lengthMeters {
                total += len
            } else {
                hasMeasured = false
            }
            let instruction = Self.instruction(from: a, to: b, edge: edge, accessibleMode: accessibleMode)
            steps.append(RouteStep(from: a, to: b, edge: edge, instruction: instruction))
        }

        return RouteResult(
            nodes: nodes,
            steps: steps,
            totalLengthMeters: hasMeasured ? total : nil,
            usedAccessibleProfile: accessibleMode,
            dataState: graph.dataState
        )
    }

    private static func instruction(from: GraphNode, to: GraphNode, edge: GraphEdge, accessibleMode: Bool) -> String {
        var parts = ["Continue to \(to.label)"]
        if let len = edge.lengthMeters {
            parts.append(String(format: "(%.0f m)", len))
        }
        if edge.edgeType == .elevator {
            parts.append("via elevator")
        }
        if accessibleMode, edge.verified == false {
            parts.append("— path not verified accessible")
        }
        return parts.joined(separator: " ")
    }
}
