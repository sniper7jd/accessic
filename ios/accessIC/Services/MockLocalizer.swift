import Foundation
import simd

/// UI / routing development only. Never use mock poses for physical AR alignment claims.
struct MockLocalizer: LocalizerClient {
    let isMock = true
    var artificialDelaySeconds: TimeInterval = 0.35

    func localize(frame: CapturedFrame) async -> LocalizationOutcome {
        let start = Date()
        if artificialDelaySeconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(artificialDelaySeconds * 1_000_000_000))
        }

        // Identity-ish placeholder in an unscaled prototype frame — not a measured Whalen pose.
        let matrix = PoseMatrix4x4(rows: [
            [1, 0, 0, 2.0],
            [0, 1, 0, 0.0],
            [0, 0, 1, -3.0],
            [0, 0, 0, 1]
        ]).simd

        let success = LocalizeSuccess(
            mapID: "whalen-floor1-prototype-mock",
            coordinateFrame: "whalen_floor1_ui_prototype",
            units: "colmap_unscaled",
            poseConvention: "T_map_from_colmap_camera",
            imageWidthPx: frame.imageWidthPx,
            imageHeightPx: frame.imageHeightPx,
            inlierCount: 48,
            positionMapXYZ: SIMD3<Float>(2.0, 0.0, -3.0),
            quaternionXYZW: SIMD4<Float>(0, 0, 0, 1),
            transformMatrixMapFromCamera: matrix
        )

        return LocalizationOutcome(
            result: .success(success),
            latencySeconds: Date().timeIntervalSince(start),
            usedMock: true,
            captureT_W_from_A: frame.T_W_from_A
        )
    }
}
