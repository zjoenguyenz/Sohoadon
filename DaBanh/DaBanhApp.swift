import SwiftUI

@main
struct DaBanhApp: App {
    @StateObject private var store = PlaylistStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
