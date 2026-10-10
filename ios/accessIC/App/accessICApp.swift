import SwiftUI

@main
struct accessICApp: App {
    @StateObject private var session = LocalizationSessionModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
