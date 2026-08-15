
import SceneKit
import Foundation

public class TracerSystem {
    private let MAX_TRACERS = 30
    private let TRACER_SPEED: Float = 300.0 // units per second
    
    private struct TracerData {
        var node: SCNNode
        var start: SCNVector3
        var end: SCNVector3
        var active: Bool
        var progress: Float
        var distance: Float
        var direction: SCNVector3
    }
    
    private var tracers: [TracerData] = []
    private var currentIndex = 0
    private weak var scene: SCNScene?
    
    public init(scene: SCNScene?) {
        self.scene = scene
        
        let tracerMat = SCNMaterial()
        tracerMat.emission.contents = PlatformColor.orange
        tracerMat.diffuse.contents = PlatformColor.yellow
        tracerMat.lightingModel = .constant
        
        for _ in 0..<MAX_TRACERS {
            let cyl = SCNCylinder(radius: 0.02, height: 1.0)
            cyl.materials = [tracerMat]
            
            let node = SCNNode(geometry: cyl)
            node.isHidden = true
            
            // Pivot so it scales/moves from origin
            node.pivot = SCNMatrix4MakeTranslation(0, 0.5, 0)
            
            scene?.rootNode.addChildNode(node)
            
            tracers.append(TracerData(node: node, start: SCNVector3Zero, end: SCNVector3Zero, active: false, progress: 0, distance: 0, direction: SCNVector3Zero))
        }
    }
    
    public func spawnTracer(start: SCNVector3, end: SCNVector3) {
        let dir = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let dist = sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
        
        guard dist > 0.001 else { return }
        
        let normDir = SCNVector3(dir.x/dist, dir.y/dist, dir.z/dist)
        
        tracers[currentIndex].active = true
        tracers[currentIndex].start = start
        tracers[currentIndex].end = end
        tracers[currentIndex].progress = 0
        tracers[currentIndex].distance = Float(dist)
        tracers[currentIndex].direction = normDir
        
        let node = tracers[currentIndex].node
        node.isHidden = false
        node.position = start
        
        // Orient tracer
        let up = SCNVector3(0, 1, 0)
        let isCollinear = abs(normDir.y) > 0.99
        let right = isCollinear ? SCNVector3(1, 0, 0) : SCNVector3(
            up.y * normDir.z - up.z * normDir.y,
            up.z * normDir.x - up.x * normDir.z,
            up.x * normDir.y - up.y * normDir.x
        )
        
        node.simdLook(at: simd_float3(Float(start.x + normDir.x), Float(start.y + normDir.y), Float(start.z + normDir.z)),
                      up: simd_float3(Float(right.x), Float(right.y), Float(right.z)),
                      localFront: simd_float3(0, 1, 0)) // Cylinder points up (Y axis)
        
        currentIndex = (currentIndex + 1) % MAX_TRACERS
    }
    
    public func update(deltaTime: Float) {
        for i in 0..<MAX_TRACERS {
            if tracers[i].active {
                tracers[i].progress += TRACER_SPEED * deltaTime
                
                if tracers[i].progress >= tracers[i].distance {
                    tracers[i].active = false
                    tracers[i].node.isHidden = true
                } else {
                    let p = tracers[i].progress
                    let dir = tracers[i].direction
                    let start = tracers[i].start
                    
                    let nx = Float(start.x) + Float(dir.x) * p
                    let ny = Float(start.y) + Float(dir.y) * p
                    let nz = Float(start.z) + Float(dir.z) * p
                    tracers[i].node.position = SCNVector3(nx, ny, nz)
                    
                    // Stretch
                    let length = min(Float(p), 5.0) // Max tracer length 5 units
                    tracers[i].node.scale = SCNVector3(1, length, 1)
                }
            }
        }
    }
}
