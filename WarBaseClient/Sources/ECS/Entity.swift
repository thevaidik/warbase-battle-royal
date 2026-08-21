import Foundation

public class Entity {
    public let id: Int
    // No lock needed — all access is on the RealityKit main thread.
    // The old NSLock added overhead to every getComponent/addComponent call
    // (2 lock acquisitions per frame per component × 6 components × 60fps = 720 lock ops/sec for nothing).
    private var components: [ObjectIdentifier: Any] = [:]
    
    public init(id: Int) {
        self.id = id
    }
    
    @inline(__always)
    public func addComponent<T: Component>(_ component: T) {
        components[ObjectIdentifier(T.self)] = component
    }
    
    @inline(__always)
    public func getComponent<T: Component>(_ type: T.Type) -> T? {
        components[ObjectIdentifier(type)] as? T
    }
    
    public func removeComponent<T: Component>(_ type: T.Type) {
        components.removeValue(forKey: ObjectIdentifier(type))
    }
    
    public func hasComponent<T: Component>(_ type: T.Type) -> Bool {
        components[ObjectIdentifier(type)] != nil
    }
}
