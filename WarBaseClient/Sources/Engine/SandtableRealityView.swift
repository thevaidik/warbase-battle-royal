import SwiftUI
import RealityKit
import simd

#if os(visionOS) || os(macOS) || os(iOS)

@available(macOS 15.0, visionOS 1.0, iOS 18.0, *)
struct SandtableRealityView: View {
    @ObservedObject var viewModel: SandtableViewModel
    
    // Scale factor: 10,000m (10km) -> 1.0m on table
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
            // Root anchor positioned directly in front of the commander
            let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.05, -0.8))
            rootAnchor = anchor
            
            // 1. Camera for macOS rendering
            #if os(macOS) || os(iOS)
            let cameraEntity = Entity()
            var cameraComp = PerspectiveCameraComponent()
            cameraComp.fieldOfViewInDegrees = 50
            cameraEntity.components.set(cameraComp)
            cameraEntity.position = SIMD3<Float>(0, 0.75, 0.65)
            cameraEntity.look(at: SIMD3<Float>(0, 0, -0.05), from: cameraEntity.position, relativeTo: nil)
            anchor.addChild(cameraEntity)
            #endif
            
            // 2. Directional & Ambient Table Lighting
            let lightEntity = Entity()
            var lightComp = DirectionalLightComponent()
            lightComp.color = .init(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            lightComp.intensity = 5000
            lightEntity.components.set(lightComp)
            lightEntity.position = SIMD3<Float>(0.5, 1.2, 0.8)
            lightEntity.look(at: SIMD3<Float>(0, 0, 0), from: lightEntity.position, relativeTo: nil)
            anchor.addChild(lightEntity)
            
            // 3. 3D Holographic Sandtable Bevel & Topography Surface
            let tableMesh = MeshResource.generateBox(width: 1.4, height: 0.03, depth: 1.0, cornerRadius: 0.015)
            var tableMaterial = SimpleMaterial()
            tableMaterial.color = .init(tint: .init(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.95))
            tableMaterial.roughness = 0.3
            tableMaterial.metallic = 0.6
            let tableEntity = ModelEntity(mesh: tableMesh, materials: [tableMaterial])
            tableEntity.position = SIMD3<Float>(0, -0.015, 0)
            anchor.addChild(tableEntity)
            
            // 4. Tactical Grid & Sector Lines
            let gridMesh = MeshResource.generatePlane(width: 1.35, depth: 0.95)
            var gridMaterial = UnlitMaterial()
            gridMaterial.color = .init(tint: .init(red: 0.0, green: 0.8, blue: 0.9, alpha: 0.35))
            let gridEntity = ModelEntity(mesh: gridMesh, materials: [gridMaterial])
            gridEntity.position = SIMD3<Float>(0, 0.002, 0)
            anchor.addChild(gridEntity)
            
            content.add(anchor)
        } update: { content in
            guard let anchor = rootAnchor else { return }
            
            updateTacticalUnits(in: anchor)
            updateDrones(in: anchor)
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
            let posY: Float = 0.015
            
            let entity: ModelEntity
            if let existing = unitEntities[unitId] {
                entity = existing
            } else {
                let isBlue = unit.faction == "BLUEFOR"
                let tokenMesh = MeshResource.generateBox(width: 0.055, height: 0.018, depth: 0.038, cornerRadius: 0.004)
                var mat = SimpleMaterial()
                mat.color = .init(tint: isBlue ? .systemCyan : .systemRed)
                mat.metallic = 0.5
                mat.roughness = 0.2
                
                entity = ModelEntity(mesh: tokenMesh, materials: [mat])
                entity.name = unitId
                entity.generateCollisionShapes(recursive: false)
                anchor.addChild(entity)
                unitEntities[unitId] = entity
            }
            
            entity.position = SIMD3<Float>(posX, posY, posZ)
            
            if viewModel.selectedUnitId == unitId {
                entity.scale = SIMD3<Float>(1.3, 1.3, 1.3)
            } else {
                entity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
            }
        }
    }
    
    private func updateDrones(in anchor: AnchorEntity) {
        for (droneId, drone) in viewModel.drones {
            let posX = drone.x * worldScale
            let posZ = drone.z * worldScale
            let posY = (drone.y * worldScale) + 0.04
            
            let entity: ModelEntity
            if let existing = droneEntities[droneId] {
                entity = existing
            } else {
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
            
            let progress = max(0.0, min(1.0, 1.0 - (mission.timeToImpact / mission.flightTimeSeconds)))
            let currentX = startX + (targetX - startX) * progress
            let currentZ = startZ + (targetZ - startZ) * progress
            let arcHeight: Float = 0.22 * sin(progress * .pi)
            let currentY = 0.015 + arcHeight
            
            let shellEntity: ModelEntity
            if let existing = trajectoryEntities[missionKey] {
                shellEntity = existing
            } else {
                let shellMesh = MeshResource.generateSphere(radius: 0.007)
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
            viewModel.selectedUnitId = entity.name
        } else if let drone = viewModel.drones[entity.name] {
            viewModel.selectedDroneId = entity.name
            viewModel.activeDronePiP = drone
        }
    }
}

#endif
