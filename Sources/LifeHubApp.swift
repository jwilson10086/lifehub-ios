import SwiftUI

@main
struct LifeHubApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "lifehub" else { return }
                    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                    let text = items.first(where: { $0.name == "text" || $0.name == "capture" })?.value
                    guard let text = text, !text.isEmpty else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .lifehubCapture, object: text)
                    }
                }
        }
    }
}
