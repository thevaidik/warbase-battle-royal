import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Standalone input manager.
/// Accumulates keyboard, mouse, and touch/joystick state, and exposes it for the render loop to consume.
/// All state is static so it survives SwiftUI Coordinator recreation and view updates.
final class InputManager {
    // MARK: - Static state
    private static var _forward = false
    private static var _backward = false
    private static var _left = false
    private static var _right = false
    private static var _jump = false
    private static var _crouch = false
    private static var _sprint = false
    private static var _fire = false
    private static var _ads = false
    private static var _reload = false
    private static var _weapon1 = false
    private static var _weapon2 = false
    private static var _grenade = false

    // Cursor lock state
    private static var _cursorLocked = false
    // Pause menu blocks ALL input processing (including auto-lock)
    private static var _pauseMenuActive = false

    // MARK: - Private
    private static let lock = NSRecursiveLock()
    #if os(macOS)
    private static var sharedMonitor: Any?
    #endif
    private static var sharedPendingDeltaX: Float = 0
    private static var sharedPendingDeltaY: Float = 0

    /// Public read-only access for cursor lock state
    static var isCursorLocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cursorLocked
    }

    /// Public read-only access for pause menu state
    static var isPauseMenuActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _pauseMenuActive
    }

    // MARK: - Callbacks
    static var onPauseToggle: (() -> Void)?
    static var onCursorLockChange: ((Bool) -> Void)?
    static var onCleanup: (() -> Void)?

    // MARK: - Mobile & External Control Setters

    static func setForward(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _forward = active
    }

    static func setBackward(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _backward = active
    }

    static func setLeft(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _left = active
    }

    static func setRight(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _right = active
    }

    static func setMovement(forward: Bool, backward: Bool, left: Bool, right: Bool, sprint: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        _forward = forward
        _backward = backward
        _left = left
        _right = right
        _sprint = sprint
    }

    static func resetMovement() {
        lock.lock()
        defer { lock.unlock() }
        _forward = false
        _backward = false
        _left = false
        _right = false
        _sprint = false
    }

    static func setJump(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _jump = active
    }

    static func setCrouch(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _crouch = active
    }

    static func toggleCrouch() {
        lock.lock()
        defer { lock.unlock() }
        _crouch.toggle()
    }

    static func setSprint(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _sprint = active
    }

    static func setFire(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _fire = active
    }

    static func setADS(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _ads = active
    }

    static func toggleADS() {
        lock.lock()
        defer { lock.unlock() }
        _ads.toggle()
    }

    static func setReload(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _reload = active
    }

    static func setWeapon1(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _weapon1 = active
    }

    static func setWeapon2(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _weapon2 = active
    }

    static func setGrenade(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _grenade = active
    }

    static func addLookDelta(dx: Float, dy: Float) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive else { return }
        sharedPendingDeltaX += dx
        sharedPendingDeltaY += dy
    }

    static func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        _forward = false
        _backward = false
        _left = false
        _right = false
        _jump = false
        _crouch = false
        _sprint = false
        _fire = false
        _ads = false
        _reload = false
        _weapon1 = false
        _weapon2 = false
        _grenade = false
        sharedPendingDeltaX = 0
        sharedPendingDeltaY = 0
    }

    // MARK: - Install (macOS)

    func install() {
        #if os(macOS)
        guard InputManager.sharedMonitor == nil else { return }
        InputManager.sharedMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp,
                       .rightMouseDown, .rightMouseUp, .mouseMoved,
                       .leftMouseDragged, .rightMouseDragged]
        ) { event -> NSEvent? in
            InputManager.lock.lock()
            defer { InputManager.lock.unlock() }

            switch event.type {
            case .flagsChanged:
                if InputManager._pauseMenuActive { return event }
                InputManager._sprint = event.modifierFlags.contains(.shift)
                return nil

            case .keyDown:
                // TAB is handled by ContentView's scoreboard monitor.
                if event.keyCode == 48 { return event }
                if InputManager._pauseMenuActive { return event }
                InputManager.handleKeyDown(event)
                return nil

            case .keyUp:
                if event.keyCode == 48 { return event }
                if InputManager._pauseMenuActive { return event }
                InputManager.handleKeyUp(event)
                return nil

            case .leftMouseDown:
                if InputManager._pauseMenuActive { return event }
                if !InputManager._cursorLocked {
                    InputManager._cursorLocked = true
                    #if os(macOS)
                    DispatchQueue.main.async {
                        CGAssociateMouseAndMouseCursorPosition(0)
                        NSCursor.hide()
                        InputManager.onCursorLockChange?(true)
                    }
                    #endif
                }
                InputManager._fire = true
                return nil

            case .leftMouseUp:
                if InputManager._pauseMenuActive { return event }
                InputManager._fire = false
                return nil

            case .rightMouseDown:
                if InputManager._pauseMenuActive { return event }
                InputManager._ads = true
                return nil

            case .rightMouseUp:
                if InputManager._pauseMenuActive { return event }
                InputManager._ads = false
                return nil

            case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
                if InputManager._pauseMenuActive { return event }
                if InputManager._cursorLocked {
                    InputManager.sharedPendingDeltaX += Float(event.deltaX)
                    InputManager.sharedPendingDeltaY += Float(event.deltaY)
                }
                return nil

            default:
                return event
            }
        }
        #endif
    }

    // MARK: - Remove

    static func remove() {
        #if os(macOS)
        if let m = sharedMonitor { NSEvent.removeMonitor(m) }
        sharedMonitor = nil
        #endif
        resetAll()
    }

    // MARK: - Cursor control

    static func lockCursor() {
        var didChange = false
        lock.lock()
        if !_cursorLocked {
            _cursorLocked = true
            didChange = true
        }
        lock.unlock()

        if didChange {
            #if os(macOS)
            DispatchQueue.main.async {
                CGAssociateMouseAndMouseCursorPosition(0)
                NSCursor.hide()
                onCursorLockChange?(true)
            }
            #endif
        }
    }

    static func unlockCursor() {
        var didChange = false
        lock.lock()
        if _cursorLocked {
            _cursorLocked = false
            didChange = true
        }
        lock.unlock()

        if didChange {
            #if os(macOS)
            DispatchQueue.main.async {
                CGAssociateMouseAndMouseCursorPosition(1)
                NSCursor.unhide()
                onCursorLockChange?(false)
            }
            #endif
        }
    }

    static func setPauseMenuActive(_ active: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _pauseMenuActive = active
    }

    // MARK: - Consume (render thread, once per frame)

    func consume() -> (input: InputState, deltaX: Float, deltaY: Float) {
        InputManager.lock.lock()
        defer { InputManager.lock.unlock() }

        var input = InputState()
        input.forward = InputManager._forward
        input.backward = InputManager._backward
        input.left = InputManager._left
        input.right = InputManager._right
        input.jump = InputManager._jump
        input.crouch = InputManager._crouch
        input.sprint = InputManager._sprint
        input.fire = InputManager._fire
        input.ads = InputManager._ads
        input.reload = InputManager._reload
        input.weapon1 = InputManager._weapon1
        input.weapon2 = InputManager._weapon2
        input.grenade = InputManager._grenade
        let dx = InputManager.sharedPendingDeltaX
        let dy = InputManager.sharedPendingDeltaY
        InputManager.sharedPendingDeltaX = 0
        InputManager.sharedPendingDeltaY = 0

        // Reset single-frame triggers
        InputManager._jump = false
        InputManager._reload = false
        InputManager._weapon1 = false
        InputManager._weapon2 = false
        InputManager._grenade = false

        return (input, dx, dy)
    }

    // MARK: - Static key & mouse handlers (macOS)
    #if os(macOS)
    static func handleMouseDown(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive else { return }
        if !_cursorLocked {
            _cursorLocked = true
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
            DispatchQueue.main.async { onCursorLockChange?(true) }
        }
        _fire = true
    }

    static func handleMouseUp(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive else { return }
        _fire = false
    }

    static func handleRightMouseDown(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive else { return }
        _ads = true
    }

    static func handleRightMouseUp(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive else { return }
        _ads = false
    }

    static func handleMouseMoved(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        guard !_pauseMenuActive, _cursorLocked else { return }
        sharedPendingDeltaX += Float(event.deltaX)
        sharedPendingDeltaY += Float(event.deltaY)
    }

    static func handleKeyDown(_ event: NSEvent) {
        NSLog("[WB-R] handleKeyDown code %d chars %@ repeat %d", event.keyCode, event.charactersIgnoringModifiers ?? "-", event.isARepeat ? 1 : 0)
        lock.lock()
        defer { lock.unlock() }
        if event.keyCode == 53 {
            _pauseMenuActive.toggle()
            if _pauseMenuActive {
                _cursorLocked = false
                CGAssociateMouseAndMouseCursorPosition(1)
                NSCursor.unhide()
            }
            DispatchQueue.main.async { onPauseToggle?() }
            return
        }
        if _pauseMenuActive { return }
        handleKeyDownStatic(event)
    }

    static func handleKeyUp(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        if _pauseMenuActive { return }
        handleKeyUpStatic(event)
    }

    static func handleFlagsChanged(_ event: NSEvent) {
        lock.lock()
        defer { lock.unlock() }
        if _pauseMenuActive { return }
        _sprint = event.modifierFlags.contains(.shift)
    }

    static func handleKeyDownStatic(_ event: NSEvent) {
        if event.isARepeat { return }
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let code = event.keyCode

        // Forward: W (13), Up Arrow (126), "w"
        if code == 13 || code == 126 || chars == "w" { _forward = true }
        // Backward: S (1), Down Arrow (125), "s"
        else if code == 1 || code == 125 || chars == "s" { _backward = true }
        // Left: A (0), Left Arrow (123), "a"
        else if code == 0 || code == 123 || chars == "a" { _left = true }
        // Right: D (2), Right Arrow (124), "d"
        else if code == 2 || code == 124 || chars == "d" { _right = true }
        // Jump: Space (49), " "
        else if code == 49 || chars == " " { _jump = true }
        // Sprint: Shift (56, 60)
        else if code == 56 || code == 60 { _sprint = true }
        // Crouch: C (8), "c"
        else if code == 8 || chars == "c" { _crouch = true }
        // Reload: R (15), "r"
        else if code == 15 || chars == "r" { _reload = true }
        // Weapon 1: 1 (18), "1"
        else if code == 18 || chars == "1" { _weapon1 = true }
        // Weapon 2: 2 (19), "2"
        else if code == 19 || chars == "2" { _weapon2 = true }
        // Grenade: G (5), "g"
        else if code == 5 || chars == "g" { _grenade = true }
    }

    static func handleKeyUpStatic(_ event: NSEvent) {
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let code = event.keyCode

        if code == 13 || code == 126 || chars == "w" { _forward = false }
        else if code == 1 || code == 125 || chars == "s" { _backward = false }
        else if code == 0 || code == 123 || chars == "a" { _left = false }
        else if code == 2 || code == 124 || chars == "d" { _right = false }
        else if code == 49 || chars == " " { _jump = false }
        else if code == 56 || code == 60 { _sprint = false }
        else if code == 8 || chars == "c" { _crouch = false }
        else if code == 15 || chars == "r" { _reload = false }
        else if code == 18 || chars == "1" { _weapon1 = false }
        else if code == 19 || chars == "2" { _weapon2 = false }
        else if code == 5 || chars == "g" { _grenade = false }
    }
    #endif
}
