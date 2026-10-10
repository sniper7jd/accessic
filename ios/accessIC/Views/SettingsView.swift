import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: LocalizationSessionModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use Mock localizer", isOn: $session.useMockLocalizer)
                        .accessibilityHint("When on, poses are synthetic and AR alignment stays disabled.")
                    if session.useMockLocalizer {
                        Text("MOCK mode is for UI and routing tests only. It must not be used to claim doorway alignment.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Localization")
                }

                Section {
                    TextField("API base URL", text: $session.apiBaseURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField("Bearer token (optional)", text: $session.authToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Prefer HTTPS via your tunnel. Temporary HTTP lab exceptions should be removed before demo day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Network")
                }

                Section {
                    LabeledContent("Min inliers") {
                        Text("\(AppConfig.minimumInlierCount)")
                    }
                    LabeledContent("Capture long edge") {
                        Text("\(AppConfig.captureLongEdgePixels) px")
                    }
                    LabeledContent("Map scope") {
                        Text(AppConfig.mapDisplayName)
                    }
                } header: {
                    Text("Client gates")
                }

                Section {
                    Text("Stage 1 shell: camera + mock localize + prototype routing. Metric scale, surveyed anchors, and verified accessible edges are later gates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
