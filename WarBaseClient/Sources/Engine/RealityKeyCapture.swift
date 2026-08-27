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
    // Keyboard + flags are handled exclusively by InputManager.install() (NSEvent local monitor).
    // This view only grabs focus so mouse deltas reach the window.
    override func keyDown(with event: NSEvent) { super.keyDown(with: event) }
    override func keyUp(with event: NSEvent) { super.keyUp(with: event) }
    override func flagsChanged(with event: NSEvent) { super.flagsChanged(with: event) }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); super.mouseDown(with: event) }
    override func mouseUp(with event: NSEvent) { super.mouseUp(with: event) }
    override func rightMouseDown(with event: NSEvent) { super.rightMouseDown(with: event) }
    override func rightMouseUp(with event: NSEvent) { super.rightMouseUp(with: event) }
    override func mouseMoved(with event: NSEvent) { super.mouseMoved(with: event) }
    override func mouseDragged(with event: NSEvent) { super.mouseDragged(with: event) }
    override func rightMouseDragged(with event: NSEvent) { super.rightMouseDragged(with: event) }
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
