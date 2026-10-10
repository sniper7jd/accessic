import Foundation
import simd

#if canImport(ARKit) && canImport(UIKit)
import ARKit
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Captures one ARFrame's image, intrinsics, size, timestamp, and T_W_from_A together.
@MainActor
final class FrameCaptureService {
    /// Stage 1 / offline capture when no AR session frame is available yet.
    func makePlaceholderFrame(T_W_from_A: simd_float4x4 = matrix_identity_float4x4) -> CapturedFrame {
        let width = 1920
        let height = 1440
        let jpeg = Self.solidJPEG(width: width, height: height, quality: AppConfig.jpegQuality) ?? Data()
        // Approximate pinhole for placeholder only — replaced by ARFrame intrinsics in Stage 4.
        let fx = Float(width) * 0.9
        let fy = fx
        let cx = Float(width) / 2
        let cy = Float(height) / 2
        return CapturedFrame(
            jpegData: jpeg,
            imageWidthPx: width,
            imageHeightPx: height,
            intrinsics3x3RowMajor: [fx, 0, cx, 0, fy, cy, 0, 0, 1],
            timestampSeconds: Date().timeIntervalSince1970,
            T_W_from_A: T_W_from_A
        )
    }

    func capture(from frame: ARFrame, longEdge: Int = AppConfig.captureLongEdgePixels) throws -> CapturedFrame {
        let pixelBuffer = frame.capturedImage
        // ARKit gives a YCbCr buffer oriented for the camera sensor; convert without unintended mirror.
        guard let uiImage = Self.uiImage(from: pixelBuffer) else {
            throw FrameCaptureError.imageConversionFailed
        }

        let originalWidth = uiImage.size.width
        let originalHeight = uiImage.size.height
        let scale = min(1.0, CGFloat(longEdge) / max(originalWidth, originalHeight))
        let targetSize = CGSize(width: floor(originalWidth * scale), height: floor(originalHeight * scale))

        let resized = scale < 1.0 ? Self.resize(uiImage, to: targetSize) : uiImage
        guard let jpeg = resized.jpegData(compressionQuality: AppConfig.jpegQuality) else {
            throw FrameCaptureError.jpegEncodeFailed
        }

        let k = frame.camera.intrinsics
        // simd_float3x3 columns; export row-major and scale fx, fy, cx, cy with the resize.
        let s = Float(scale)
        let fx = k.columns.0.x * s
        let fy = k.columns.1.y * s
        let cx = k.columns.2.x * s
        let cy = k.columns.2.y * s

        return CapturedFrame(
            jpegData: jpeg,
            imageWidthPx: Int(targetSize.width),
            imageHeightPx: Int(targetSize.height),
            intrinsics3x3RowMajor: [fx, 0, cx, 0, fy, cy, 0, 0, 1],
            timestampSeconds: frame.timestamp,
            T_W_from_A: frame.camera.transform
        )
    }

    private static func uiImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // Keep upright relative to the buffer; orientation corrections belong with known AR display transforms later.
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    private static func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func solidJPEG(width: Int, height: Int, quality: CGFloat) -> Data? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: quality)
    }
}

enum FrameCaptureError: Error, LocalizedError {
    case imageConversionFailed
    case jpegEncodeFailed
    case noCurrentFrame

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Could not convert the AR frame image."
        case .jpegEncodeFailed: return "Could not encode JPEG."
        case .noCurrentFrame: return "No AR frame is available yet. Wait for tracking to start."
        }
    }
}
#else

/// Non-Apple stub so the sources remain readable outside Xcode; not used at runtime on iOS.
struct FrameCaptureService {
    func makePlaceholderFrame(T_W_from_A: simd_float4x4 = matrix_identity_float4x4) -> CapturedFrame {
        CapturedFrame(
            jpegData: Data(),
            imageWidthPx: 1920,
            imageHeightPx: 1440,
            intrinsics3x3RowMajor: [1700, 0, 960, 0, 1700, 720, 0, 0, 1],
            timestampSeconds: 0,
            T_W_from_A: T_W_from_A
        )
    }
}

enum FrameCaptureError: Error {
    case imageConversionFailed
    case jpegEncodeFailed
    case noCurrentFrame
}
#endif
