import SwiftUI

@main
struct AIToyApp: App {
    @StateObject private var environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            RootView(consentStore: environment.consentStore)
                .environmentObject(environment)
                .preferredColorScheme(.light)
        }
    }
}

private struct RootView: View {
    @ObservedObject var consentStore: ConsentStore

    var body: some View {
        Group {
            if consentStore.hasGuardianConsent {
                StoryListView()
            } else {
                ConsentView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: consentStore.hasGuardianConsent)
    }
}
