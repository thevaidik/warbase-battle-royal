import SwiftUI

/// On-screen touch controls for iOS:
/// - Virtual Joystick (left side) for 4-direction movement (WASD) and sprint
/// - Touch look/drag area (right side) for camera pitch and yaw
/// - Action triggers for Fire, ADS, Jump, Crouch, Reload, Grenade, Weapon Switch, and Pause
public struct MobileControlsView: View {
    @ObservedObject var gameVM: GameViewModel
    
    // Joystick state
    @State private var joystickOffset: CGSize = .zero
    @State private var isDraggingJoystick = false
    private let joystickRadius: CGFloat = 55
    private let knobRadius: CGFloat = 24
    
    // Look drag state
    @State private var lastLookLocation: CGPoint? = nil
    
    // ADS toggle state
    @State private var isADSActive = false
    @State private var isCrouchActive = false
    
    init(gameVM: GameViewModel) {
        self.gameVM = gameVM
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Touch Look / Drag Surface (Right Half)
                HStack(spacing: 0) {
                    // Left half reserved for joystick
                    Color.clear
                        .frame(width: geometry.size.width * 0.45)
                    
                    // Right half captures drag for looking around
                    Color.clear
                        .frame(width: geometry.size.width * 0.55)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if let last = lastLookLocation {
                                        let dx = Float(value.location.x - last.x)
                                        let dy = Float(value.location.y - last.y)
                                        // Ignore sudden multi-touch teleportation / transition jumps (> 150pt)
                                        if abs(dx) < 150 && abs(dy) < 150 {
                                            InputManager.addLookDelta(dx: dx * 6.0, dy: dy * 6.0)
                                        }
                                    }
                                    lastLookLocation = value.location
                                }
                                .onEnded { _ in
                                    lastLookLocation = nil
                                }
                        )
                }
                
                // MARK: - UI Controls Overlay
                VStack {
                    // Top Bar: Pause Button & Weapon Switch
                    HStack {
                        Spacer()
                        
                        // Weapon Switch Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                InputManager.setWeapon1(true)
                            }) {
                                Text("PRI")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 34)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            Button(action: {
                                InputManager.setWeapon2(true)
                            }) {
                                Text("SEC")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 34)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.trailing, 10)
                        
                        // Pause Button
                        Button(action: {
                            gameVM.showPauseMenu.toggle()
                            if gameVM.showPauseMenu {
                                InputManager.setPauseMenuActive(true)
                            } else {
                                InputManager.setPauseMenuActive(false)
                            }
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Bottom Controls: Virtual Joystick (Left) & Actions (Right)
                    HStack(alignment: .bottom) {
                        // Virtual Joystick
                        joystickView
                            .padding(.leading, 36)
                            .padding(.bottom, 36)
                        
                        Spacer()
                        
                        // Action Buttons Cluster
                        actionButtonsCluster
                            .padding(.trailing, 28)
                            .padding(.bottom, 28)
                    }
                }
            }
        }
    }
    
    // MARK: - Virtual Movement Joystick
    
    private var joystickView: some View {
        ZStack {
            // Joystick Outer Ring
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: joystickRadius * 2, height: joystickRadius * 2)
                .overlay(
                    Circle()
                        .stroke(isDraggingJoystick ? Color.cyan.opacity(0.8) : Color.white.opacity(0.25), lineWidth: 2)
                )
            
            // Directional indicators
            VStack {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(height: joystickRadius * 1.5)
            
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: joystickRadius * 1.5)
            
            // Inner Knob
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [isDraggingJoystick ? Color.cyan : Color.white.opacity(0.9), Color.gray]),
                        center: .center,
                        startRadius: 2,
                        endRadius: knobRadius
                    )
                )
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .shadow(color: isDraggingJoystick ? Color.cyan.opacity(0.5) : Color.black.opacity(0.4), radius: 6)
                .offset(joystickOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDraggingJoystick = true
                    let translation = value.translation
                    let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                    
                    let clampedDistance = min(distance, joystickRadius)
                    let angle = atan2(translation.height, translation.width)
                    
                    let offsetX = cos(angle) * clampedDistance
                    let offsetY = sin(angle) * clampedDistance
                    joystickOffset = CGSize(width: offsetX, height: offsetY)
                    
                    // Normalize inputs (-1.0 ... 1.0)
                    let normX = Float(offsetX / joystickRadius)
                    let normY = Float(offsetY / joystickRadius)
                    
                    let deadzone: Float = 0.2
                    let forward = normY < -deadzone
                    let backward = normY > deadzone
                    let left = normX < -deadzone
                    let right = normX > deadzone
                    let isSprinting = (distance > joystickRadius * 0.75) && (normY < -0.4)
                    
                    InputManager.setMovement(
                        forward: forward,
                        backward: backward,
                        left: left,
                        right: right,
                        sprint: isSprinting
                    )
                }
                .onEnded { _ in
                    isDraggingJoystick = false
                    withAnimation(.easeOut(duration: 0.15)) {
                        joystickOffset = .zero
                    }
                    InputManager.resetMovement()
                }
        )
    }
    
    // MARK: - Action Buttons Cluster
    
    private var actionButtonsCluster: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Row 1: Grenade & Reload
            HStack(spacing: 14) {
                // Grenade
                Button(action: {
                    InputManager.setGrenade(true)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 48, height: 48)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                
                // Reload
                Button(action: {
                    InputManager.setReload(true)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 48, height: 48)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
            }
            
            // Row 2: ADS & Jump
            HStack(spacing: 14) {
                // ADS (Aim Down Sights) Toggle
                Button(action: {
                    isADSActive.toggle()
                    InputManager.setADS(isADSActive)
                }) {
                    ZStack {
                        Circle()
                            .fill(isADSActive ? Color.cyan.opacity(0.4) : Color.black.opacity(0.5))
                            .frame(width: 52, height: 52)
                        Image(systemName: "scope")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isADSActive ? .cyan : .white)
                    }
                    .overlay(
                        Circle().stroke(isADSActive ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                }
                
                // Jump Button
                Button(action: {
                    InputManager.setJump(true)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 54, height: 54)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                }
            }
            
            // Row 3: Crouch & Fire Button
            HStack(spacing: 16) {
                // Crouch Button
                Button(action: {
                    isCrouchActive.toggle()
                    InputManager.setCrouch(isCrouchActive)
                }) {
                    ZStack {
                        Circle()
                            .fill(isCrouchActive ? Color.purple.opacity(0.4) : Color.black.opacity(0.5))
                            .frame(width: 50, height: 50)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isCrouchActive ? .purple : .white)
                    }
                    .overlay(
                        Circle().stroke(isCrouchActive ? Color.purple : Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                }
                
                // Fire Button (Holdable for auto-fire)
                fireButtonView
            }
        }
    }
    
    // MARK: - Fire Button
    
    @State private var isFiring = false
    
    private var fireButtonView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            isFiring ? Color.red : Color.red.opacity(0.7),
                            Color.red.opacity(0.4)
                        ]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 36
                    )
                )
                .frame(width: 72, height: 72)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: Color.red.opacity(0.5), radius: isFiring ? 10 : 4)
            
            Image(systemName: "target")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isFiring {
                        isFiring = true
                        InputManager.setFire(true)
                    }
                }
                .onEnded { _ in
                    isFiring = false
                    InputManager.setFire(false)
                }
        )
    }
}
