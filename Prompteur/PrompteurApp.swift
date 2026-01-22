import SwiftUI

@main
struct PrompteurApp: App {
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
        }
    }
}
