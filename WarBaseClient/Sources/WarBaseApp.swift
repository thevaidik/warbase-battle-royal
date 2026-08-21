import SwiftUI

@main
struct WarBaseApp: App {
    init() { NSLog("[WB-R] WarBaseApp init") }
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
    }
}
