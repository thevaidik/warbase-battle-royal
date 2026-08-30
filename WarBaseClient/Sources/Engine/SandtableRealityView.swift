import SwiftUI
import RealityKit
import simd

#if os(visionOS) || os(macOS) || os(iOS)

@available(macOS 15.0, visionOS 1.0, iOS 18.0, *)
struct SandtableRealityView: View {
    @ObservedObject var viewModel: SandtableViewModel
    
    // Scale factor to map kilometers into tabletop scale (e.g. 10km = 1.0m table)
    private let worldScale: Float = 0.0001
    
    @State private var unitEntities: [String: ModelEntity] = [:]
    @State private var droneEntities: [String: ModelEntity] = [:]
    @State private var trajectoryEntities: [String: ModelEntity] = [:]
    @State private var rootAnchor: AnchorEntity?
    
    init(viewModel: SandtableViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 1.0, -1.2))
            rootAnchor = anchor
            
            // 1. Build 3D Holographic Sandtable Topography Base
            let tableMesh = MeshResource.generateBox(width: 1.6, height: 0.04, depth: 1.2, cornerRadius: 0.02)
            var tableMaterial = SimpleMaterial()
            tableMaterial.color = .init(tint: .black.withAlphaComponent(0.85), texture: nil)
            tableMaterial.roughness = 0.2
            tableMaterial.metallic = 0.8
            let tableEntity = ModelEntity(mesh: tableMesh, materials: [tableMaterial])
            tableEntity.position = SIMD3<Float>(0, 0, 0)
            anchor.addChild(tableEntity)
            
            // 2. Holographic Tactical Grid Lines
            let gridMesh = MeshResource.generatePlane(width: 1.5, depth: 1.1)
            var gridMaterial = UnlitMaterial()
            gridMaterial.color = .init(tint: .cyan.withAlphaComponent(0.25))
            let gridEntity = ModelEntity(mesh: gridMesh, materials: [gridMaterial])
            gridEntity.position = SIMD3<Float>(0, 0.022, 0)
            anchor.addChild(gridEntity)
            
            content.add(anchor)
        } update: { content in
            guard let anchor = rootAnchor else { return }
            
            // Update Tactical Units
            updateTacticalUnits(in: anchor)
            
            // Update Drones
            updateDrones(in: anchor)
            
            // Update Ballistic Trajectories
            updateArtilleryTrajectories(in: anchor)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleSpatialTap(entity: value.entity)
                }
        )
    }
    
    private func updateTacticalUnits(in anchor: AnchorEntity) {
        for (unitId, unit) in viewModel.units {
            let posX = unit.x * worldScale
            let posZ = unit.z * worldScale
            let posY: Float = 0.035
            
            let entity: ModelEntity
            if let existing = unitEntities[unitId] {
                entity = existing
            } else {
                // Generate 3D NATO Unit Token Counter
                let isBlue = unit.faction == "BLUEFOR"
                let tokenMesh = MeshResource.generateBox(width: 0.045, height: 0.015, depth: 0.035, cornerRadius: 0.003)
                var mat = SimpleMaterial()
                mat.color = .init(tint: isBlue ? .systemCyan : .systemRed)
                mat.metallic = 0.4
                mat.roughness = 0.3
                
                entity = ModelEntity(mesh: tokenMesh, materials: [mat])
                entity.name = unitId
                entity.generateCollisionShapes(recursive: false)
                anchor.addChild(entity)
                unitEntities[unitId] = entity
            }
            
            // Animate / update position
            entity.position = SIMD3<Float>(posX, posY, posZ)
            
            // Selection highlight
            if viewModel.selectedUnitId == unitId {
                entity.scale = SIMD3<Float>(1.25, 1.25, 1.25)
            } else {
                entity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            }
        }
    }
    
    private func updateDrones(in anchor: AnchorEntity) {
        for (droneId, drone) in viewModel.drones {
            let posX = drone.x * worldScale
            let posZ = drone.z * worldScale
            let posY = (drone.y * worldScale) + 0.05
            
            let entity: ModelEntity
            if let existing = droneEntities[droneId] {
                entity = existing
            } else {
                // Drone 3D Hologram Marker
                let droneMesh = MeshResource.generateSphere(radius: 0.012)
                var mat = UnlitMaterial()
                mat.color = .init(tint: drone.faction == "BLUEFOR" ? .yellow : .orange)
                entity = ModelEntity(mesh: droneMesh, materials: [mat])
                entity.name = droneId
                entity.generateCollisionShapes(recursive: false)
                anchor.addChild(entity)
                droneEntities[droneId] = entity
            }
            
            entity.position = SIMD3<Float>(posX, posY, posZ)
        }
    }
    
    private func updateArtilleryTrajectories(in anchor: AnchorEntity) {
        for mission in viewModel.fireMissions {
            let missionKey = mission.missionID
            
            let startX = mission.originX * worldScale
            let startZ = mission.originZ * worldScale
            let targetX = mission.targetX * worldScale
            let targetZ = mission.targetZ * worldScale
            
            // Flight progression (0.0 to 1.0)
            let progress = max(0.0, min(1.0, 1.0 - (mission.timeToImpact / mission.flightTimeSeconds)))
            
            // Parabolic arc height
            let currentX = startX + (targetX - startX) * progress
            let currentZ = startZ + (targetZ - startZ) * progress
            let arcHeight: Float = 0.25 * sin(progress * .pi)
            let currentY = 0.035 + arcHeight
            
            let shellEntity: ModelEntity
            if let existing = trajectoryEntities[missionKey] {
                shellEntity = existing
            } else {
                let shellMesh = MeshResource.generateSphere(radius: 0.006)
                var mat = UnlitMaterial()
                mat.color = .init(tint: .yellow)
                shellEntity = ModelEntity(mesh: shellMesh, materials: [mat])
                anchor.addChild(shellEntity)
                trajectoryEntities[missionKey] = shellEntity
            }
            
            shellEntity.position = SIMD3<Float>(currentX, currentY, currentZ)
        }
    }
    
    private func handleSpatialTap(entity: RealityKit.Entity) {
        if let _ = viewModel.units[entity.name] {
            // Selected a unit token
            viewModel.selectedUnitId = entity.name
        } else if let drone = viewModel.drones[entity.name] {
            // Selected a drone
            viewModel.selectedDroneId = entity.name
            viewModel.activeDronePiP = drone
        }
    }
}

#endif
