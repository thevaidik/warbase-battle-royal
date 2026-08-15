import Foundation

public class World {
    public private(set) var entities: [Int: Entity] = [:]
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
        nextEntityId = 1
    }
}
