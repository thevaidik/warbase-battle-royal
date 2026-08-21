import SwiftUI

struct LoadingView: View {
    let status: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Text("WARBASE")
                    .font(.system(size: 64, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(12)

                Text(status)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    .scaleEffect(1.5)

                Spacer()
            }
        }
    }
}
