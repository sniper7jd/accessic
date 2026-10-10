import SwiftUI
import simd

#if canImport(RealityKit) && canImport(ARKit)
import RealityKit
import ARKit

struct ARNavigationView: View {
    @EnvironmentObject private var session: LocalizationSessionModel

    var body: some View {
        ZStack(alignment: .top) {
            ARViewContainer(session: session)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                if session.useMockLocalizer {
                    Text("MOCK — AR world anchors disabled")
                        .font(.caption.weight(.bold))
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.95))
                        .foregroundStyle(.black)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(session.statusText)
                        .font(.footnote)
                    if !session.physicalARAlignmentEnabled {
                        Text("Physical AR placement requires live localize + units=meters.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                Spacer()

                Button {
                    Task { await session.localize() }
                } label: {
                    Label(session.isLocating ? "Locating…" : "Locate Me", systemImage: "location.fill")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isLocating)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("AR")
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var session: LocalizationSessionModel

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.delegate = context.coordinator
        arView.session.run(config)
        context.coordinator.arView = arView

        session.latestARFrameProvider = { [weak coordinator = context.coordinator] in
            coordinator?.captureFrame()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.session = session
        // Stage 1: never place mock-derived world anchors.
        if !session.physicalARAlignmentEnabled {
            context.coordinator.clearAnchors()
        }
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        var session: LocalizationSessionModel
        weak var arView: ARView?
        private let captureService = FrameCaptureService()

        init(session: LocalizationSessionModel) {
            self.session = session
        }

        func session(_ sessionAR: ARSession, didUpdate frame: ARFrame) {
            self.session.latestT_W_from_A = frame.camera.transform
        }

        func captureFrame() -> CapturedFrame? {
            guard let frame = arView?.session.currentFrame else { return nil }
            return try? captureService.capture(from: frame)
        }

        func clearAnchors() {
            arView?.scene.anchors.removeAll()
        }
    }
}
#else

struct ARNavigationView: View {
    var body: some View {
        Text("ARKit/RealityKit required. Open this target in Xcode on a Mac.")
            .padding()
    }
}
#endif
