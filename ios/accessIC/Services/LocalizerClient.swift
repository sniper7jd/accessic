import Foundation
import simd

/// One captured ARKit frame ready for upload or mock localization.
struct CapturedFrame: Sendable {
    let jpegData: Data
    let imageWidthPx: Int
    let imageHeightPx: Int
    /// Row-major 3×3 intrinsics matching the uploaded pixels.
    let intrinsics3x3RowMajor: [Float]
    let timestampSeconds: TimeInterval
    /// ARKit camera transform at capture time (T_W_from_A). Do not replace with a later pose.
    let T_W_from_A: simd_float4x4
}

struct LocalizationOutcome: Sendable {
    let result: LocalizeResult
    let latencySeconds: TimeInterval
    let usedMock: Bool
    /// Echo of the capture-time transform for alignment after the network round-trip.
    let captureT_W_from_A: simd_float4x4
}

protocol LocalizerClient: Sendable {
    var isMock: Bool { get }
    func localize(frame: CapturedFrame) async -> LocalizationOutcome
}

extension LocalizerClient {
    func rejectLowConfidence(_ success: LocalizeSuccess) -> LocalizeResult {
        if success.inlierCount < AppConfig.minimumInlierCount {
            return .failure(
                LocalizeFailure(
                    errorCode: .lowConfidence,
                    message: "Inlier count \(success.inlierCount) is below the client threshold of \(AppConfig.minimumInlierCount). Point toward distinctive hallway features and try again.",
                    inlierCount: success.inlierCount
                )
            )
        }
        return .success(success)
    }
}
