import SwiftUI

/// Primary navigation surface for Stage 1. Prototype graph only.
struct FloorMapView: View {
    @EnvironmentObject private var session: LocalizationSessionModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if session.useMockLocalizer {
                    MockBanner()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppConfig.mapDisplayName)
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)

                        Text(session.statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Localization status: \(session.statusText)")

                        if let error = session.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Error: \(error)")
                        }

                        PrototypePlanCanvas(route: session.route, graph: session.graph)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1.4, contentMode: .fit)
                            .accessibilityLabel("Prototype floor plan canvas. Not a calibrated blueprint.")

                        controls
                    }
                    .padding()
                }
            }
            .navigationTitle("accessIC")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let graph = session.graph {
                Picker("From", selection: $session.startNodeID) {
                    ForEach(graph.nodes) { node in
                        Text(node.label).tag(node.id)
                    }
                }
                .accessibilityLabel("Start location")

                Picker("To", selection: $session.goalNodeID) {
                    ForEach(graph.nodes) { node in
                        Text(node.label).tag(node.id)
                    }
                }
                .accessibilityLabel("Destination")
            }

            Toggle("Accessible mode (exclude stairs)", isOn: $session.accessibleMode)
                .accessibilityHint("When on, stair edges are removed from routing.")

            HStack(spacing: 12) {
                Button {
                    Task { await session.localize() }
                } label: {
                    if session.isLocating {
                        Label("Locating…", systemImage: "location.magnifyingglass")
                    } else {
                        Label("Locate Me", systemImage: "location.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isLocating)
                .accessibilityHint("Uploads a camera frame or uses mock localization.")

                Button("Show Route") {
                    session.computeRoute()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Computes a path on the loaded graph.")
            }

            if let route = session.route {
                VStack(alignment: .leading, spacing: 6) {
                    Text(route.isPrototype ? "Prototype route" : "Route")
                        .font(.headline)
                    if let meters = route.totalLengthMeters {
                        Text(String(format: "About %.0f meters (graph lengths)", meters))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(route.steps) { step in
                        Text("• \(step.instruction)")
                            .font(.footnote)
                    }
                }
                .padding(.top, 4)
            }

            Text("Whalen 1st floor technical prototype. Not Business School–H&S navigation.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct MockBanner: View {
    var body: some View {
        Text("MOCK — not physical alignment")
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.9))
            .foregroundStyle(.black)
            .accessibilityLabel("Mock localization active. Not physical alignment.")
    }
}

/// Simple schematic — not a calibrated Whalen blueprint.
private struct PrototypePlanCanvas: View {
    let route: RouteResult?
    let graph: FloorGraph?

    var body: some View {
        GeometryReader { geo in
            let nodes = graph?.nodes ?? []
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(Color.gray.opacity(0.12)))

                // Corridor backdrop
                var hall = Path()
                hall.addRect(CGRect(x: size.width * 0.1, y: size.height * 0.35, width: size.width * 0.8, height: size.height * 0.2))
                context.fill(hall, with: .color(Color.gray.opacity(0.25)))

                if let route {
                    var path = Path()
                    for (index, node) in route.nodes.enumerated() {
                        let p = project(node, in: size)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    context.stroke(path, with: .color(.blue), lineWidth: 4)
                }

                for node in nodes {
                    let p = project(node, in: size)
                    let dot = Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
                    context.fill(dot, with: .color(color(for: node.kind)))
                    context.draw(
                        Text(node.label).font(.system(size: 9)),
                        at: CGPoint(x: p.x, y: p.y - 14),
                        anchor: .center
                    )
                }

                context.draw(
                    Text("UI PROTOTYPE").font(.system(size: 11, weight: .bold)),
                    at: CGPoint(x: rect.midX, y: 16),
                    anchor: .center
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.3))
        )
    }

    private func project(_ node: GraphNode, in size: CGSize) -> CGPoint {
        // Prototype coordinates are schematic, not map meters.
        let minX: Float = -1
        let maxX: Float = 12
        let minZ: Float = -4
        let maxZ: Float = 4
        let u = CGFloat((node.x - minX) / (maxX - minX))
        let v = CGFloat((node.z - minZ) / (maxZ - minZ))
        return CGPoint(x: u * size.width, y: v * size.height)
    }

    private func color(for kind: GraphNodeKind) -> Color {
        switch kind {
        case .elevator: return .purple
        case .stairs: return .red
        case .room, .door: return .teal
        case .ramp: return .green
        default: return .primary
        }
    }
}
