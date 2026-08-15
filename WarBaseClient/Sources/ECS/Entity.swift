import Foundation

public class Entity {
    public let id: Int
    private var components: [ObjectIdentifier: Component] = [:]
    
    public init(id: Int) {
        self.id = id
    }
    
    public func addComponent<T: Component>(_ component: T) {
        components[ObjectIdentifier(T.self)] = component
    }
    
    public func getComponent<T: Component>(_ type: T.Type) -> T? {
        return components[ObjectIdentifier(type)] as? T
    }
    
    public func removeComponent<T: Component>(_ type: T.Type) {
        components.removeValue(forKey: ObjectIdentifier(type))
    }
    
    public func hasComponent<T: Component>(_ type: T.Type) -> Bool {
        return components[ObjectIdentifier(type)] != nil
    }
}
