import SwiftUI
import AppKit

#if os(macOS)
final class KeyCaptureNSView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        window?.acceptsMouseMovedEvents = true
    }
    override func keyDown(with event: NSEvent) { NSLog("[WB-R] KeyCapture keyDown %d", event.keyCode); InputManager.handleKeyDown(event) }
    override func keyUp(with event: NSEvent) { NSLog("[WB-R] KeyCapture keyUp %d", event.keyCode); InputManager.handleKeyUp(event) }
    override func flagsChanged(with event: NSEvent) { InputManager.handleFlagsChanged(event) }
    override func mouseDown(with event: NSEvent) { InputManager.handleMouseDown(event); window?.makeFirstResponder(self) }
    override func mouseUp(with event: NSEvent) { InputManager.handleMouseUp(event) }
    override func rightMouseDown(with event: NSEvent) { InputManager.handleRightMouseDown(event) }
    override func rightMouseUp(with event: NSEvent) { InputManager.handleRightMouseUp(event) }
    override func mouseMoved(with event: NSEvent) { InputManager.handleMouseMoved(event) }
    override func mouseDragged(with event: NSEvent) { InputManager.handleMouseMoved(event) }
    override func rightMouseDragged(with event: NSEvent) { InputManager.handleMouseMoved(event) }
}

struct KeyCaptureView: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let v = KeyCaptureNSView(frame: .zero)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
    }
}
#endif
