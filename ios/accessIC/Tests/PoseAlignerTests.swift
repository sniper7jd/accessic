import XCTest
import simd
@testable import accessIC

final class PoseAlignerTests: XCTestCase {
    let aligner = PoseAligner()

    func testC_A_from_C_isDiagonalFlipYZ() {
        let m = PoseAligner.C_A_from_C
        XCTAssertEqual(m.columns.0.x, 1, accuracy: 1e-6)
        XCTAssertEqual(m.columns.1.y, -1, accuracy: 1e-6)
        XCTAssertEqual(m.columns.2.z, -1, accuracy: 1e-6)
        XCTAssertEqual(m.columns.3.w, 1, accuracy: 1e-6)
    }

    func testIdentityCaptureAndServerYieldsAxisConversionOnly() {
        let T_W_from_A = matrix_identity_float4x4
        let T_M_from_C = matrix_identity_float4x4
        let T_W_from_M = aligner.mapToWorld(T_W_from_A: T_W_from_A, T_M_from_C: T_M_from_C)
        // T_W_from_M = I · C · I = C
        assertAlmostEqual(T_W_from_M, PoseAligner.C_A_from_C)
    }

    func testTranslationInMapMovesWorldPoint() {
        // Server pose: camera at (2, 0, -3) with identity rotation in map frame.
        var T_M_from_C = matrix_identity_float4x4
        T_M_from_C.columns.3 = SIMD4<Float>(2, 0, -3, 1)

        let T_W_from_A = matrix_identity_float4x4
        let T_W_from_M = aligner.mapToWorld(T_W_from_A: T_W_from_A, T_M_from_C: T_M_from_C)

        // Point at the camera center in map should map near the ARKit camera origin after alignment.
        let cameraCenter_M = SIMD3<Float>(2, 0, -3)
        let world = aligner.mapPointToWorld(point_M: cameraCenter_M, T_W_from_M: T_W_from_M)
        XCTAssertEqual(world.x, 0, accuracy: 1e-4)
        XCTAssertEqual(world.y, 0, accuracy: 1e-4)
        XCTAssertEqual(world.z, 0, accuracy: 1e-4)
    }

    func testRowMajorJSONConvertsToSimdColumns() {
        let rows: [[Float]] = [
            [1, 0, 0, 1.5],
            [0, 1, 0, 2.5],
            [0, 0, 1, 3.5],
            [0, 0, 0, 1]
        ]
        let matrix = PoseMatrix4x4(rows: rows).simd
        XCTAssertEqual(matrix.columns.3.x, 1.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.3.y, 2.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.3.z, 3.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.0.x, 1, accuracy: 1e-6)
    }

    func testSimdRoundTripRowMajor() {
        let original = PoseMatrix4x4(rows: [
            [0, 0, 1, 4],
            [1, 0, 0, 5],
            [0, 1, 0, 6],
            [0, 0, 0, 1]
        ])
        let roundTrip = PoseMatrix4x4(simd: original.simd)
        for (a, b) in zip(original.rowMajor, roundTrip.rowMajor) {
            XCTAssertEqual(a, b, accuracy: 1e-5)
        }
    }

    func testInverseOfTranslation() {
        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4<Float>(3, -2, 1, 1)
        let inv = PoseMath.inverse(t)
        let product = t * inv
        assertAlmostEqual(product, matrix_identity_float4x4)
    }

    func testPhysicalAnchorsRequireMetersAndNonMock() {
        XCTAssertFalse(aligner.mayPlacePhysicalAnchors(units: "colmap_unscaled", isMock: false))
        XCTAssertFalse(aligner.mayPlacePhysicalAnchors(units: "meters", isMock: true))
        XCTAssertTrue(aligner.mayPlacePhysicalAnchors(units: "meters", isMock: false))
    }

    func testDecodeSuccessAndRejectFailureWithPose() throws {
        let successJSON = """
        {
          "status": "success",
          "map_id": "whalen-floor1-v1",
          "coordinate_frame": "whalen_floor1_map",
          "units": "colmap_unscaled",
          "pose_convention": "T_map_from_colmap_camera",
          "image_width_px": 1920,
          "image_height_px": 1440,
          "inlier_count": 40,
          "position_map_xyz": [1.0, 2.0, 3.0],
          "quaternion_xyzw": [0.0, 0.0, 0.0, 1.0],
          "transform_matrix_map_from_camera": [
            [1, 0, 0, 1.0],
            [0, 1, 0, 2.0],
            [0, 0, 1, 3.0],
            [0, 0, 0, 1.0]
          ]
        }
        """.data(using: .utf8)!

        let decoder = LocalizeResponseDecoder()
        let result = try decoder.decode(data: successJSON)
        guard case .success(let s) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(s.inlierCount, 40)
        XCTAssertEqual(s.positionMapXYZ.x, 1, accuracy: 1e-5)

        let badFailure = """
        {
          "status": "failed",
          "error_code": "insufficient_inliers",
          "error": "not enough",
          "position_map_xyz": [0, 0, 0]
        }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(data: badFailure))
    }

    private func assertAlmostEqual(_ a: simd_float4x4, _ b: simd_float4x4, accuracy: Float = 1e-4) {
        for c in 0..<4 {
            for r in 0..<4 {
                XCTAssertEqual(a[c][r], b[c][r], accuracy: accuracy)
            }
        }
    }
}
