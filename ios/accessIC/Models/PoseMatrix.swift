import Foundation
import simd

/// Row-major 4×4 matrix as received in JSON, convertible to simd column-major.
struct PoseMatrix4x4: Equatable, Sendable {
    /// Sixteen elements in row-major order: r0c0, r0c1, r0c2, r0c3, r1c0, ...
    var rowMajor: [Float]

    init(rowMajor: [Float]) {
        precondition(rowMajor.count == 16, "Expected 16 floats for a 4x4 matrix")
        self.rowMajor = rowMajor
    }

    init(rows: [[Float]]) {
        precondition(rows.count == 4 && rows.allSatisfy { $0.count == 4 })
        self.rowMajor = rows.flatMap { $0 }
    }

    init(simd matrix: simd_float4x4) {
        // simd_float4x4 stores columns; export as row-major for JSON parity.
        var values = [Float](repeating: 0, count: 16)
        for row in 0..<4 {
            for col in 0..<4 {
                values[row * 4 + col] = matrix[col][row]
            }
        }
        self.rowMajor = values
    }

    var simd: simd_float4x4 {
        // JSON / scientific convention is row-major; simd is column-major.
        let m = rowMajor
        return simd_float4x4(
            SIMD4<Float>(m[0], m[4], m[8], m[12]),
            SIMD4<Float>(m[1], m[5], m[9], m[13]),
            SIMD4<Float>(m[2], m[6], m[10], m[14]),
            SIMD4<Float>(m[3], m[7], m[11], m[15])
        )
    }

    static let identity = PoseMatrix4x4(rows: [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1]
    ])
}

enum PoseMath {
    static func inverse(_ matrix: simd_float4x4) -> simd_float4x4 {
        matrix.inverse
    }

    static func transformPoint(_ matrix: simd_float4x4, point: SIMD3<Float>) -> SIMD3<Float> {
        let p = matrix * SIMD4<Float>(point.x, point.y, point.z, 1)
        return SIMD3<Float>(p.x, p.y, p.z)
    }

    /// Quaternion xyzw → rotation matrix (column-major simd).
    static func matrixFromQuaternionXYZW(_ q: SIMD4<Float>) -> simd_float4x4 {
        let x = q.x, y = q.y, z = q.z, w = q.w
        let xx = x * x, yy = y * y, zz = z * z
        let xy = x * y, xz = x * z, yz = y * z
        let wx = w * x, wy = w * y, wz = w * z

        let c0 = SIMD4<Float>(1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), 0)
        let c1 = SIMD4<Float>(2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), 0)
        let c2 = SIMD4<Float>(2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), 0)
        let c3 = SIMD4<Float>(0, 0, 0, 1)
        return simd_float4x4(c0, c1, c2, c3)
    }
}
