import Foundation

public class World {
    // Direct access — no lock, no copy. The game loop is single-threaded (render thread).
    // Network callbacks only ADD/REMOVE entities, never modify components.
    public var entities: [Int: Entity] = [:]
    private var nextEntityId = 1
    
    public init() {}
    
    public func createEntity() -> Int {
        let id = nextEntityId
        nextEntityId += 1
        entities[id] = Entity(id: id)
        return id
    }
    
    public func removeEntity(id: Int) {
        entities.removeValue(forKey: id)
    }
    
    public func clearAll() {
        entities.removeAll()
        // keep nextEntityId monotonic to avoid id reuse after re-enter (M1 leak guard)
    }
}
