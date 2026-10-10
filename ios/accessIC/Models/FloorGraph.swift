import Foundation
import simd

enum GraphDataState: String, Codable, Sendable {
    /// Sample nodes for UI / Dijkstra tests only. Not surveyed Whalen coordinates.
    case uiPrototype = "ui_prototype"
    /// Surveyed nodes in the calibrated map frame with verified accessibility attributes.
    case liveMap = "live_map"
}

enum GraphNodeKind: String, Codable, Sendable {
    case corridor
    case room
    case elevator
    case stairs
    case ramp
    case door
    case landmark
}

enum EdgeType: String, Codable, Sendable {
    case corridor
    case door
    case elevator
    case stairs
    case ramp
    case unknown
}

enum DoorOperability: String, Codable, Sendable {
    case automatic
    case manual
    case unknown
}

enum EdgeStatus: String, Codable, Sendable {
    case open
    case closed
    case unknown
}

struct GraphNode: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let label: String
    let kind: GraphNodeKind
    let x: Float
    let y: Float
    let z: Float

    var position: SIMD3<Float> { SIMD3(x, y, z) }
}

struct GraphEdge: Identifiable, Codable, Equatable, Sendable {
    var id: String { "\(from)->\(to)" }

    let from: String
    let to: String
    let edgeType: EdgeType
    let lengthMeters: Float?
    let hasStairs: Bool?
    let slopePct: Float?
    let clearWidthCm: Float?
    let thresholdCm: Float?
    let doorOperability: DoorOperability?
    let status: EdgeStatus
    /// Only `true` means verified for live guidance. Unknown must stay unknown.
    let verified: Bool

    enum CodingKeys: String, CodingKey {
        case from, to
        case edgeType = "edge_type"
        case lengthMeters = "length_meters"
        case hasStairs = "has_stairs"
        case slopePct = "slope_pct"
        case clearWidthCm = "clear_width_cm"
        case thresholdCm = "threshold_cm"
        case doorOperability = "door_operability"
        case status, verified
    }
}

struct FloorGraph: Codable, Equatable, Sendable {
    let dataState: GraphDataState
    let mapID: String
    let coordinateFrame: String
    let units: String
    let notes: String?
    let nodes: [GraphNode]
    let edges: [GraphEdge]

    enum CodingKeys: String, CodingKey {
        case dataState = "data_state"
        case mapID = "map_id"
        case coordinateFrame = "coordinate_frame"
        case units, notes, nodes, edges
    }

    var isPrototype: Bool { dataState == .uiPrototype }

    func node(id: String) -> GraphNode? {
        nodes.first { $0.id == id }
    }

    static func loadPrototypeFromBundle(
        name: String = AppConfig.prototypeGraphResource,
        bundle: Bundle = .main
    ) throws -> FloorGraph {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FloorGraphError.missingResource(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FloorGraph.self, from: data)
    }
}

enum FloorGraphError: Error, LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing floor graph resource: \(name).json"
        }
    }
}
