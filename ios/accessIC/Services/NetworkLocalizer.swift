import Foundation
import simd

/// Posts JPEG + calibration metadata to the frozen `/localize` contract.
/// HTTP 200 alone is never treated as success — `status` in JSON is required.
struct NetworkLocalizer: LocalizerClient {
    let isMock = false
    var baseURL: URL
    var authToken: String?
    var session: URLSession
    private let decoder = LocalizeResponseDecoder()

    init(
        baseURL: URL,
        authToken: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = session
    }

    func localize(frame: CapturedFrame) async -> LocalizationOutcome {
        let start = Date()
        do {
            let request = try makeRequest(frame: frame)
            let (data, response) = try await session.data(for: request)
            let latency = Date().timeIntervalSince(start)

            guard let http = response as? HTTPURLResponse else {
                return failureOutcome(
                    .network("Missing HTTP response"),
                    latency: latency,
                    capture: frame.T_W_from_A
                )
            }

            guard (200...299).contains(http.statusCode) else {
                return failureOutcome(
                    code: .httpError,
                    message: "Server returned HTTP \(http.statusCode)",
                    latency: latency,
                    capture: frame.T_W_from_A
                )
            }

            let parsed = try decoder.decode(data: data)
            let gated: LocalizeResult
            switch parsed {
            case .success(let success):
                gated = rejectLowConfidence(success)
            case .failure:
                gated = parsed
            }

            return LocalizationOutcome(
                result: gated,
                latencySeconds: latency,
                usedMock: false,
                captureT_W_from_A: frame.T_W_from_A
            )
        } catch let error as LocalizeClientError {
            return failureOutcome(error, latency: Date().timeIntervalSince(start), capture: frame.T_W_from_A)
        } catch {
            return failureOutcome(
                .network(error.localizedDescription),
                latency: Date().timeIntervalSince(start),
                capture: frame.T_W_from_A
            )
        }
    }

    private func makeRequest(frame: CapturedFrame) throws -> URLRequest {
        let endpoint = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + AppConfig.localizePath
        guard let finalURL = URL(string: endpoint) else {
            throw LocalizeClientError.encodingFailed
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.timeoutInterval = AppConfig.requestTimeoutSeconds

        let boundary = "accessic-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let intrinsicsJSON = try JSONSerialization.data(
            withJSONObject: [
                [frame.intrinsics3x3RowMajor[0], frame.intrinsics3x3RowMajor[1], frame.intrinsics3x3RowMajor[2]],
                [frame.intrinsics3x3RowMajor[3], frame.intrinsics3x3RowMajor[4], frame.intrinsics3x3RowMajor[5]],
                [frame.intrinsics3x3RowMajor[6], frame.intrinsics3x3RowMajor[7], frame.intrinsics3x3RowMajor[8]]
            ]
        )

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "image_width_px", value: String(frame.imageWidthPx))
        appendField(name: "image_height_px", value: String(frame.imageHeightPx))
        appendField(name: "intrinsics_3x3", value: String(data: intrinsicsJSON, encoding: .utf8) ?? "[]")
        appendField(name: "timestamp_seconds", value: String(frame.timestampSeconds))

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"query.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(frame.jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return request
    }

    private func failureOutcome(
        _ error: LocalizeClientError,
        latency: TimeInterval,
        capture: simd_float4x4
    ) -> LocalizationOutcome {
        let failure: LocalizeFailure
        switch error {
        case .httpStatus:
            failure = LocalizeFailure(errorCode: .httpError, message: error.localizedDescription ?? "HTTP error", inlierCount: nil)
        case .invalidResponse(let detail):
            failure = LocalizeFailure(errorCode: .invalidResponse, message: detail, inlierCount: nil)
        case .network(let detail):
            failure = LocalizeFailure(errorCode: .network, message: detail, inlierCount: nil)
        case .encodingFailed:
            failure = LocalizeFailure(errorCode: .invalidImage, message: error.localizedDescription ?? "Encoding failed", inlierCount: nil)
        }
        return LocalizationOutcome(result: .failure(failure), latencySeconds: latency, usedMock: false, captureT_W_from_A: capture)
    }

    private func failureOutcome(
        code: LocalizeErrorCode,
        message: String,
        latency: TimeInterval,
        capture: simd_float4x4
    ) -> LocalizationOutcome {
        LocalizationOutcome(
            result: .failure(LocalizeFailure(errorCode: code, message: message, inlierCount: nil)),
            latencySeconds: latency,
            usedMock: false,
            captureT_W_from_A: capture
        )
    }
}
