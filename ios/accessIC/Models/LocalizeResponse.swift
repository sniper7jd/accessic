import Foundation
import simd

enum LocalizeStatus: String, Codable, Sendable {
    case success
    case failed
}

enum LocalizeErrorCode: String, Codable, Sendable {
    case insufficientInliers = "insufficient_inliers"
    case invalidImage = "invalid_image"
    case unsupportedFormat = "unsupported_format"
    case missingCalibration = "missing_calibration"
    case internalError = "internal_error"
    case mapUnavailable = "map_unavailable"
    case network = "network"
    case invalidResponse = "invalid_response"
    case lowConfidence = "low_confidence"
    case httpError = "http_error"
}

/// Frozen success payload. `transformMatrixMapFromCamera` is authoritative (T_M_from_C).
struct LocalizeSuccess: Equatable, Sendable {
    let mapID: String
    let coordinateFrame: String
    let units: String
    let poseConvention: String
    let imageWidthPx: Int
    let imageHeightPx: Int
    let inlierCount: Int
    let positionMapXYZ: SIMD3<Float>
    let quaternionXYZW: SIMD4<Float>
    let transformMatrixMapFromCamera: simd_float4x4

    var isMetric: Bool { units == "meters" }
}

struct LocalizeFailure: Equatable, Sendable {
    let errorCode: LocalizeErrorCode
    let message: String
    let inlierCount: Int?
}

enum LocalizeResult: Equatable, Sendable {
    case success(LocalizeSuccess)
    case failure(LocalizeFailure)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Decodes the frozen schema. Rejects success-shaped JSON that is missing the matrix.
struct LocalizeResponseDecoder {
    func decode(data: Data) throws -> LocalizeResult {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw LocalizeClientError.invalidResponse("Root JSON must be an object")
        }
        guard let status = dict["status"] as? String else {
            throw LocalizeClientError.invalidResponse("Missing status")
        }

        switch status {
        case "success":
            return .success(try decodeSuccess(dict))
        case "failed":
            return .failure(try decodeFailure(dict))
        default:
            throw LocalizeClientError.invalidResponse("Unknown status: \(status)")
        }
    }

    private func decodeSuccess(_ dict: [String: Any]) throws -> LocalizeSuccess {
        // Failed poses must never look successful: require the authoritative matrix.
        guard
            let mapID = dict["map_id"] as? String,
            let coordinateFrame = dict["coordinate_frame"] as? String,
            let units = dict["units"] as? String,
            let poseConvention = dict["pose_convention"] as? String,
            let imageWidth = Self.int(dict["image_width_px"]),
            let imageHeight = Self.int(dict["image_height_px"]),
            let inliers = Self.int(dict["inlier_count"]),
            let position = Self.floatArray(dict["position_map_xyz"], count: 3),
            let quat = Self.floatArray(dict["quaternion_xyzw"], count: 4),
            let matrixRows = Self.floatMatrix4x4(dict["transform_matrix_map_from_camera"])
        else {
            throw LocalizeClientError.invalidResponse("Success payload missing required fields")
        }

        guard poseConvention == "T_map_from_colmap_camera" else {
            throw LocalizeClientError.invalidResponse("Unexpected pose_convention: \(poseConvention)")
        }

        let matrix = PoseMatrix4x4(rows: matrixRows).simd
        let xyz = SIMD3<Float>(position[0], position[1], position[2])
        let q = SIMD4<Float>(quat[0], quat[1], quat[2], quat[3])

        return LocalizeSuccess(
            mapID: mapID,
            coordinateFrame: coordinateFrame,
            units: units,
            poseConvention: poseConvention,
            imageWidthPx: imageWidth,
            imageHeightPx: imageHeight,
            inlierCount: inliers,
            positionMapXYZ: xyz,
            quaternionXYZW: q,
            transformMatrixMapFromCamera: matrix
        )
    }

    private func decodeFailure(_ dict: [String: Any]) throws -> LocalizeFailure {
        guard
            let codeRaw = dict["error_code"] as? String,
            let message = dict["error"] as? String
        else {
            throw LocalizeClientError.invalidResponse("Failure payload missing error_code/error")
        }

        // Pose fields must not be trusted on failure even if a buggy server includes them.
        if dict["transform_matrix_map_from_camera"] != nil || dict["position_map_xyz"] != nil {
            throw LocalizeClientError.invalidResponse("Failure response must not include pose fields")
        }

        let code = LocalizeErrorCode(rawValue: codeRaw) ?? .invalidResponse
        let inliers = Self.int(dict["inlier_count"])
        return LocalizeFailure(errorCode: code, message: message, inlierCount: inliers)
    }

    private static func int(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    private static func floatArray(_ value: Any?, count: Int) -> [Float]? {
        guard let arr = value as? [Any], arr.count == count else { return nil }
        var out: [Float] = []
        out.reserveCapacity(count)
        for item in arr {
            if let f = item as? Float {
                out.append(f)
            } else if let d = item as? Double {
                out.append(Float(d))
            } else if let n = item as? NSNumber {
                out.append(n.floatValue)
            } else {
                return nil
            }
        }
        return out
    }

    private static func floatMatrix4x4(_ value: Any?) -> [[Float]]? {
        guard let rows = value as? [Any], rows.count == 4 else { return nil }
        var out: [[Float]] = []
        for row in rows {
            guard let floats = floatArray(row, count: 4) else { return nil }
            out.append(floats)
        }
        return out
    }
}

enum LocalizeClientError: Error, LocalizedError, Equatable {
    case invalidResponse(String)
    case network(String)
    case httpStatus(Int)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let detail): return "Invalid localization response: \(detail)"
        case .network(let detail): return "Network error: \(detail)"
        case .httpStatus(let code): return "Server returned HTTP \(code)"
        case .encodingFailed: return "Failed to encode localization request"
        }
    }
}
