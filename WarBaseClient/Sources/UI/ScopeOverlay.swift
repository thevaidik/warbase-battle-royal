import SwiftUI

public struct ScopeOverlay: View {
    @Binding var isVisible: Bool
    
    public init(isVisible: Binding<Bool>) {
        self._isVisible = isVisible
    }
    
    public var body: some View {
        if isVisible {
            GeometryReader { geometry in
                let size = geometry.size
                let scopeDiameter = size.height * 0.7
                
                ZStack {
                    // Black vignette exterior
                    Color.black
                        .mask(
                            Rectangle()
                                .overlay(
                                    Circle()
                                        .frame(width: scopeDiameter, height: scopeDiameter)
                                        .blendMode(.destinationOut)
                                )
                        )
                        .compositingGroup()
                    
                    // Tactical crosshair lines
                    Path { path in
                        // Horizontal line
                        path.move(to: CGPoint(x: size.width / 2 - scopeDiameter / 2, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width / 2 + scopeDiameter / 2, y: size.height / 2))
                        
                        // Vertical line
                        path.move(to: CGPoint(x: size.width / 2, y: size.height / 2 - scopeDiameter / 2))
                        path.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2 + scopeDiameter / 2))
                    }
                    .stroke(Color.black, lineWidth: 2)
                    
                    // 3 red bullet-drop distance markings
                    VStack(spacing: 20) {
                        Spacer().frame(height: scopeDiameter / 2 + 30)
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 20, height: 2)
                        }
                    }
                    
                    // Glowing red center dot reticle
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .shadow(color: .red, radius: 4, x: 0, y: 0)
                }
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            }
        }
    }
}
