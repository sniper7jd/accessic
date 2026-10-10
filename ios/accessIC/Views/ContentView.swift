import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: LocalizationSessionModel

    var body: some View {
        TabView {
            FloorMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            ARNavigationView()
                .tabItem {
                    Label("AR", systemImage: "camera.viewfinder")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.teal)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocalizationSessionModel())
}
