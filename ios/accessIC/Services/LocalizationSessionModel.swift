import Foundation
import simd
import SwiftUI

@MainActor
final class LocalizationSessionModel: ObservableObject {
    @Published var useMockLocalizer: Bool {
        didSet { UserDefaults.standard.set(useMockLocalizer, forKey: AppConfig.Keys.useMockLocalizer) }
    }
    @Published var apiBaseURLString: String {
        didSet { UserDefaults.standard.set(apiBaseURLString, forKey: AppConfig.Keys.apiBaseURL) }
    }
    @Published var authToken: String {
        didSet { UserDefaults.standard.set(authToken, forKey: AppConfig.Keys.authToken) }
    }
    @Published var accessibleMode: Bool {
        didSet { UserDefaults.standard.set(accessibleMode, forKey: AppConfig.Keys.accessibleMode) }
    }

    @Published private(set) var isLocating = false
    @Published private(set) var statusText = "Point toward hallway features, then Locate Me."
    @Published private(set) var lastOutcome: LocalizationOutcome?
    @Published private(set) var lastError: String?
    @Published private(set) var graph: FloorGraph?
    @Published private(set) var route: RouteResult?
    @Published var startNodeID: String = "proto_entrance"
    @Published var goalNodeID: String = "proto_elevator"

    /// Set only when a live, metric success is available. Stage 1 mock never sets this for AR placement.
    @Published private(set) var T_W_from_M: simd_float4x4?
    @Published private(set) var physicalARAlignmentEnabled = false

    private let captureService = FrameCaptureService()
    private let aligner = PoseAligner()
    let speech = SpeechGuide()

    /// Latest ARKit camera transform; updated by ARNavigationView.
    var latestT_W_from_A: simd_float4x4 = matrix_identity_float4x4
    var latestARFrameProvider: (() -> CapturedFrame?)?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: AppConfig.Keys.useMockLocalizer) == nil {
            self.useMockLocalizer = true
        } else {
            self.useMockLocalizer = defaults.bool(forKey: AppConfig.Keys.useMockLocalizer)
        }
        self.apiBaseURLString = defaults.string(forKey: AppConfig.Keys.apiBaseURL) ?? AppConfig.defaultBaseURL
        self.authToken = defaults.string(forKey: AppConfig.Keys.authToken) ?? ""
        self.accessibleMode = defaults.object(forKey: AppConfig.Keys.accessibleMode) as? Bool ?? true
        loadGraph()
    }

    func loadGraph() {
        do {
            graph = try FloorGraph.loadPrototypeFromBundle()
            statusText = "Loaded UI prototype graph. Not surveyed Whalen coordinates."
        } catch {
            graph = nil
            lastError = error.localizedDescription
        }
    }

    func localize() async {
        guard !isLocating else { return }
        isLocating = true
        lastError = nil
        statusText = "Locating…"
        physicalARAlignmentEnabled = false
        T_W_from_M = nil

        let frame: CapturedFrame
        if let provided = latestARFrameProvider?() {
            frame = provided
        } else {
            // Stage 1 fallback when AR frame capture is not hooked up yet.
            frame = captureService.makePlaceholderFrame(T_W_from_A: latestT_W_from_A)
        }

        let client: any LocalizerClient
        if useMockLocalizer {
            client = MockLocalizer()
        } else if let url = URL(string: apiBaseURLString), !apiBaseURLString.contains("YOUR_TUNNEL") {
            client = NetworkLocalizer(baseURL: url, authToken: authToken.isEmpty ? nil : authToken)
        } else {
            isLocating = false
            lastError = "Set a real API base URL in Settings, or enable Mock localizer."
            statusText = "Localization not started."
            return
        }

        let outcome = await client.localize(frame: frame)
        lastOutcome = outcome

        switch outcome.result {
        case .success(let success):
            if outcome.usedMock {
                statusText = String(
                    format: "MOCK pose · inliers %d · %.2fs — not physical alignment",
                    success.inlierCount,
                    outcome.latencySeconds
                )
                physicalARAlignmentEnabled = false
                T_W_from_M = nil
            } else {
                statusText = String(
                    format: "Localized · inliers %d · %.2fs · units=%@",
                    success.inlierCount,
                    outcome.latencySeconds,
                    success.units
                )
                let allow = aligner.mayPlacePhysicalAnchors(units: success.units, isMock: false)
                if allow {
                    T_W_from_M = aligner.mapToWorld(
                        T_W_from_A: outcome.captureT_W_from_A,
                        T_M_from_C: success.transformMatrixMapFromCamera
                    )
                    physicalARAlignmentEnabled = true
                } else {
                    T_W_from_M = nil
                    physicalARAlignmentEnabled = false
                    statusText += " · AR anchors disabled until units=meters"
                }
            }
        case .failure(let failure):
            lastError = failure.message
            statusText = "Localization failed: \(failure.errorCode.rawValue)"
            physicalARAlignmentEnabled = false
            T_W_from_M = nil
        }

        isLocating = false
    }

    func computeRoute() {
        guard let graph else {
            lastError = "No floor graph loaded."
            return
        }
        do {
            let engine = RouteEngine(graph: graph)
            let result = try engine.route(
                from: startNodeID,
                to: goalNodeID,
                accessibleMode: accessibleMode
            )
            route = result
            if result.isPrototype {
                statusText = "Prototype route drawn. Not verified Whalen navigation."
            }
            speech.announceRoute(result)
        } catch {
            route = nil
            lastError = error.localizedDescription
        }
    }
}
