import CoreGraphics
import Foundation

/// Runtime configuration for localization and routing.
/// Physical AR alignment stays disabled until the map reports verified meters
/// and Mock mode is off.
enum AppConfig {
    static let defaultBaseURL = "https://YOUR_TUNNEL_OR_CAMPUS_HOST"
    static let localizePath = "/localize"
    static let minimumInlierCount = 12
    static let captureLongEdgePixels = 1920
    static let jpegQuality: CGFloat = 0.8
    static let requestTimeoutSeconds: TimeInterval = 30
    static let prototypeGraphResource = "whalen_floor1_graph.prototype"
    static let mapDisplayName = "Whalen Center · 1st floor"

    /// UserDefaults keys
    enum Keys {
        static let useMockLocalizer = "useMockLocalizer"
        static let apiBaseURL = "apiBaseURL"
        static let authToken = "authToken"
        static let accessibleMode = "accessibleMode"
    }
}
