import Foundation
import simd

/// Single place for COLMAP ↔ ARKit axis conversion and map-to-world alignment.
///
/// Frames:
/// - M: map (Whalen reconstruction)
/// - C: COLMAP camera (X right, Y down, Z forward)
/// - A: ARKit camera (Y up, local Z toward user)
/// - W: ARKit world
///
/// Alignment:
///   T_W_from_M = T_W_from_A · C_A_from_C · inverse(T_M_from_C)
///
/// This is a rigid alignment only. It cannot correct an unscaled COLMAP reconstruction.
struct PoseAligner: Sendable {
    /// COLMAP camera → ARKit camera axis conversion for the documented conventions.
    static let C_A_from_C = simd_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, -1, 0, 0),
        SIMD4<Float>(0, 0, -1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )

    /// - Parameters:
    ///   - T_W_from_A: `ARFrame.camera.transform` at the exact capture time.
    ///   - T_M_from_C: server `transform_matrix_map_from_camera`.
    func mapToWorld(
        T_W_from_A: simd_float4x4,
        T_M_from_C: simd_float4x4
    ) -> simd_float4x4 {
        let T_C_from_M = T_M_from_C.inverse
        return T_W_from_A * Self.C_A_from_C * T_C_from_M
    }

    func mapPointToWorld(
        point_M: SIMD3<Float>,
        T_W_from_M: simd_float4x4
    ) -> SIMD3<Float> {
        PoseMath.transformPoint(T_W_from_M, point: point_M)
    }

    /// Physical AR placement requires verified metric units and a non-mock localize.
    func mayPlacePhysicalAnchors(units: String, isMock: Bool) -> Bool {
        units == "meters" && !isMock
    }
}
