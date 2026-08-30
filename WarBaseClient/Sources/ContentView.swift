import SwiftUI

/// Root view: Presents the 3D Holographic Sandtable and Grand Strategy Command HUD
public struct ContentView: View {
    @StateObject private var viewModel = SandtableViewModel()
    @State private var hasConnected = false

    public init() {}

    public var body: some View {
        ZStack {
            #if os(visionOS) || os(macOS) || os(iOS)
            if #available(macOS 15.0, visionOS 1.0, iOS 18.0, *) {
                SandtableRealityView(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
            }
            #endif

            SandtableHUDView(viewModel: viewModel)
        }
        .frame(minWidth: 1200, minHeight: 780)
        .onAppear {
            if !hasConnected {
                hasConnected = true
                viewModel.connect(host: "127.0.0.1:8081", room: "theatre-donbas")
            }
        }
    }
}
