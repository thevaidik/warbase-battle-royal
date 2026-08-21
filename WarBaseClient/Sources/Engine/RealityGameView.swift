import SwiftUI
import RealityKit
import QuartzCore
import _RealityKit_SwiftUI
import Combine
import simd

@MainActor
final class RealityCoordinator: ObservableObject {
    var world = World()
    var viewMaps = RealityViewMaps()
    var playerSystem: RealityPlayerSystem!
    var movementSystem: RealityPlayerMovementSystem!
    var multiplayer = RealityMultiplayer()
    var lastTime: TimeInterval = 0
    var selectedClass: String = "ASSAULT"
    var coordinatorUsername: String = ""
    var coordinatorRoom: String = ""
    var networkManager: NetworkManager?
    var gameVM: GameViewModel?
    let inputManager = InputManager()
    let weaponSystem = RealityWeaponSystem()
    let tracerSystem = RealityTracerSystem()
    let decalSystem = RealityDecalSystem()
    let impactSystem = RealityImpactSystem()
    @Published var skybox: EnvironmentResource?
    @Published var ready = false
    @Published var loadingStatus = "BOOTING ENGINE..."
    private var loadingSpinners: [RealityKit.Entity] = []
    var subs: [EventSubscription] = []

    func setup<C>(_ content: C) async where C: RealityViewContentProtocol {
        NSLog("[WB-R] RealityCoordinator setup start")
        buildLoadingScene(content)
        playerSystem = RealityPlayerSystem(world: world, viewMaps: viewMaps)
        movementSystem = RealityPlayerMovementSystem()
        movementSystem.spawnPoint = [0,2,0]

        loadingStatus = "LOADING ENVIRONMENT..."
        // Daytime lighting: HDR IBL + shadowed sun + subtle fill (no blowout)
        if let env = try? await EnvironmentResource.load(named: "venice_sunset_1k") {
            skybox = env
            let ibl = RealityKit.Entity()
            ibl.name = "imageBasedLight"
            ibl.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 0.6))
            content.add(ibl)
        }
        let sun = DirectionalLight()
        sun.name = "sun"
        sun.light = DirectionalLightComponent(color: .init(red: 1.0, green: 0.97, blue: 0.92, alpha: 1), intensity: 2000)
        sun.shadow = DirectionalLightComponent.Shadow(shadowProjection: .automatic(maximumDistance: 120), depthBias: 0.01)
        sun.position = [40, 60, 20]
        sun.look(at: .zero, from: [40, 60, 20], relativeTo: nil)
        content.add(sun)
        // Subtle fill (was 60000 → blowout)
        let fill = RealityKit.Entity()
        fill.name = "ambientFill"
        fill.components.set(PointLightComponent(color: .white, intensity: 800, attenuationRadius: 150))
        fill.position = [0, 25, 0]
        content.add(fill)

        loadingStatus = "LOADING MAP..."
        // Map + safety floor first, then find spawn via downward raycast
        var spawn = SIMD3<Float>(0, 2, 0)
        var mapFloorY: Float = -100
        if let url = Bundle.main.url(forResource: "industrial", withExtension: "usdz") {
            if let map = try? await ModelEntity(contentsOf: url) {
                map.name = "industrial"
                fixMaterials(map)
                // generateCollisionShapes() makes ONE convex hull over the whole
                // (merged-mesh) map -> players walk on its invisible bbox "ceiling".
                // Instead: per-child box collisions aligned to each rendered mesh.
                await addPerMeshCollision(to: map)
                let mb = map.visualBounds(relativeTo: nil)
                mapFloorY = mb.min.y - 2
                NSLog("[WB-R] map visual bounds min=\(mb.min) max=\(mb.max)")
                content.add(map)
            }
        }
        let floor = RealityKit.Entity()
        floor.name = "floorCollision"
        floor.position.y = mapFloorY
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: 2000, height: 1, depth: 2000)]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.9, restitution: 0), mode: .static))
        content.add(floor)

        // Raycast straight down from high above origin to land on real ground
        if let scene = floor.scene {
            let probes: [SIMD2<Float>] = [[0,0],[5,0],[-5,0],[0,5],[0,-5],[8,8],[-8,-8],[12,0],[-12,0],[0,12],[0,-12],[15,15],[-15,-15]]
            var bestGroundY: Float = .infinity
            for (i, p2) in probes.enumerated() {
                let origin = SIMD3<Float>(p2.x, 60, p2.y)
                let hits = scene.raycast(origin: origin, direction: [0,-1,0], length: 120, query: .all, mask: .all)
                    .filter { $0.entity.name != "floorCollision" && $0.entity.name != "localPlayer" }
                if let ground = hits.min(by: { $0.position.y < $1.position.y }) {
                    NSLog("[WB-R] probe \(i) at (\(p2.x),\(p2.y)) ground=\(ground.position.y) hits=\(hits.count)")
                    if ground.position.y < bestGroundY {
                        bestGroundY = ground.position.y
                        spawn = SIMD3<Float>(Float(p2.x), ground.position.y + 1.0, Float(p2.y))
                    }
                }
            }
            NSLog("[WB-R] final spawn \(spawn) (lowest ground)")
        }

        loadingStatus = "LOADING SOLDIER..."
        let player = await playerSystem.initPlayer(spawnPosition: spawn)
        movementSystem.localPlayerId = playerSystem.localPlayerId
        movementSystem.spawnPoint = spawn
        content.add(player)
        if let anchor = viewMaps.cameraAnchor {
            // Visible sky dome (follows camera) so sky is never black
            addSkyDome(to: anchor)
        }
        if let net = networkManager {
            let username = coordinatorUsername
            let room = coordinatorRoom
            net.connect(username: username, room: room)
            // Wire RealityWeaponSystem fire feedback
            net.onHitConfirmed = { [weak self] _, _ in
                DispatchQueue.main.async { self?.gameVM?.crosshairColor = .red; DispatchQueue.main.asyncAfter(deadline: .now()+0.1) { self?.gameVM?.crosshairColor = .white } }
            }
            net.onKillConfirmed = { [weak self] targetId in
                DispatchQueue.main.async { self?.gameVM?.showKillFeed = true; self?.gameVM?.killFeedText = "KILLED \(targetId)" }
            }
            net.onStateReceived = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    for (id, st) in state.players where id != username && self.multiplayer.players[id] == nil {
                        let mesh = self.multiplayer.spawn(id: id, state: st)
                        content.add(mesh)
                    }
                    self.multiplayer.updateNetworkState(gameState: state, localUsername: username)
                }
            }
        }
        inputManager.install()
        lastTime = CACurrentMediaTime()
        let sub = await MainActor.run { content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(delta: Float(event.deltaTime), content: content)
        } }
        subs.append(sub)
        loadingStatus = "BINDING ANIMATIONS..."
        // Loading scene done its job
        for e in loadingSpinners { e.removeFromParent() }
        loadingSpinners.removeAll()
        loadingStatus = "READY"
        ready = true

        if CommandLine.arguments.contains("--autodeploy") {
            NSLog("[WB-R] setup spawn [0,2,0] scheduling auto-W")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { InputManager.setForward(true); NSLog("[WB-R] W down") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { InputManager.setForward(false); NSLog("[WB-R] W up") }
        }
    }

    // Simple "RealityKit magic" loading scene: orbiting glowing wireframe crates
    // around a center crate, spinning until the map/soldier finish loading.
    private func buildLoadingScene<C>(_ content: C) where C: RealityViewContentProtocol {
        let center = ModelEntity(mesh: .generateBox(size: 1.2), materials: [SimpleMaterial(color: .init(red: 0.9, green: 0.25, blue: 0.15, alpha: 1), isMetallic: false)])
        center.position = [0, 1.4, -4]
        content.add(center)
        loadingSpinners.append(center)

        for i in 0..<6 {
            let orbiter = ModelEntity(
                mesh: .generateBox(size: 0.45),
                materials: [SimpleMaterial(color: .init(red: 0.95, green: 0.55, blue: 0.2, alpha: 1), isMetallic: false)])
            let a = Float(i) / 6 * 2 * .pi
            orbiter.position = [sin(a) * 2.2, 1.4 + sin(a * 2) * 0.4, -4 + cos(a) * 2.2]
            content.add(orbiter)
            loadingSpinners.append(orbiter)
        }

        let sun = DirectionalLight()
        sun.light.intensity = 1500
        sun.position = [2, 4, 2]
        sun.look(at: [0, 1.4, -4], from: [2, 4, 2], relativeTo: nil)
        content.add(sun)
        loadingSpinners.append(sun)
    }

    private func spinLoadingScene(dt: Float) {
        guard !loadingSpinners.isEmpty else { return }
        let t = CACurrentMediaTime()
        for (i, e) in loadingSpinners.enumerated() {
            e.orientation = simd_quatf(angle: Float(t) * (0.5 + Float(i % 3) * 0.2), axis: [0.2, 1, 0.1])
        }
    }

    func tick<C>(delta: Float, content: C) where C: RealityViewContentProtocol {
        guard delta > 0, delta < 0.1 else { return }
        spinLoadingScene(dt: delta)
        let (input, dx, dy) = inputManager.consume()
        var full = input
        full.mouseDeltaX = dx
        full.mouseDeltaY = dy
        if let e = world.entities[playerSystem.localPlayerId] {
            e.addComponent(full)
        }
        movementSystem.update(deltaTime: delta, world: world, viewMaps: viewMaps, scene: nil)
        tracerSystem.update(delta: delta)
        // Weapon (firing + reload + sway + recoil + tracer/hit)
        if let e = world.entities[playerSystem.localPlayerId],
           var wep = e.getComponent(WeaponState.self),
           var recoil = e.getComponent(RecoilState.self),
           var sway = e.getComponent(SwayState.self),
           let swayRoot = viewMaps.swayRoot,
           let camEntity = viewMaps.cameraEntity,
           let player = viewMaps.player,
           let scene = player.scene {
            let isAssault = wep.activeWeaponIndex == 0
            let t = CACurrentMediaTime()
            weaponSystem.update(input: full, entity: e, weaponState: &wep, recoilState: &recoil, swayState: &sway, time: t, dt: delta, swayRoot: swayRoot, camera: camEntity, scene: scene, tracer: tracerSystem, impact: impactSystem, decal: decalSystem, network: networkManager, content: content, isAssault: isAssault)
            e.addComponent(wep); e.addComponent(recoil); e.addComponent(sway)
            let isAssaultSend = isAssault
            let snapInput = full; let snapWep = wep
            if CACurrentMediaTime() - lastTime >= 0.016 { lastTime = CACurrentMediaTime(); DispatchQueue.main.async { [weak self] in self?.sendNetworkState(input: snapInput, weaponState: snapWep, isAssault: isAssaultSend) } }
        }
        multiplayer.interpolate(currentTime: CACurrentMediaTime())
        frameCount += 1
        if frameCount == 30, let soldier = viewMaps.soldier {
            // Bone world positions -> empirical orientation check
            func find(_ needle: String) -> RealityKit.Entity? {
                var queue: [RealityKit.Entity] = [soldier]
                while !queue.isEmpty {
                    let e = queue.removeFirst()
                    if e.name.lowercased().contains(needle.lowercased()) { return e }
                    queue.append(contentsOf: e.children)
                }
                return nil
            }
            for bone in ["Head", "LeftFoot", "RightHand", "LeftHand", "Hips"] {
                if let b = find(bone) {
                    let wp = b.position(relativeTo: nil)
                    NSLog("[WB-R] bone %@ world=(%.2f, %.2f, %.2f)", bone, wp.x, wp.y, wp.z)
                }
            }
        }
        if frameCount % 60 == 0, let player = viewMaps.player {
            let pos = player.position
            let camPos = viewMaps.cameraEntity?.position(relativeTo: nil) ?? .zero
            let st = world.entities[playerSystem.localPlayerId]?.getComponent(PlayerComponentState.self)
            let sb = viewMaps.soldier?.visualBounds(relativeTo: nil)
            NSLog("[WB-R] f=\(frameCount) player=(%.2f,%.2f,%.2f) cam=(%.2f,%.2f,%.2f) grounded=\(st?.isGrounded ?? false) yaw=%.1f soldierExtents=(%.2f,%.2f,%.2f) soldierMin=(%.2f,%.2f,%.2f)",
                  pos.x,pos.y,pos.z, camPos.x,camPos.y,camPos.z, st?.yaw ?? 0,
                  sb?.extents.x ?? 0, sb?.extents.y ?? 0, sb?.extents.z ?? 0,
                  sb?.min.x ?? 0, sb?.min.y ?? 0, sb?.min.z ?? 0)
        }
    }

    private func sendNetworkState(input: InputState, weaponState: WeaponState, isAssault: Bool) {
        guard let node = viewMaps.player else { return }
        let pos = node.position
        let rot = node.orientation
        let anim = movementSystem.currentAnim.isEmpty ? "idle" : movementSystem.currentAnim.lowercased()
        let wid: String = {
            if weaponState.activeWeaponIndex == 1 { return "pistol" }
            return isAssault ? "ak47" : "m2010"
        }()
        let st = NetworkPlayerState(id: coordinatorUsername, x: Float(pos.x), y: Float(pos.y), z: Float(pos.z), rx: Float(rot.imag.x), ry: Float(rot.imag.y), rz: Float(rot.imag.z), rw: Float(rot.real), anim: anim, health: 100, kills: 0, deaths: 0, isDead: false, platformId: "", ping: 0, weaponId: wid, team: "A")
        networkManager?.sendState(state: st)
    }

    func tick(delta: Float) {
        guard delta > 0, delta < 0.1 else { return }
        let (input, dx, dy) = inputManager.consume()
        var full = input
        full.mouseDeltaX = dx
        full.mouseDeltaY = dy
        if let e = world.entities[playerSystem.localPlayerId] {
            e.addComponent(full)
        }
        movementSystem.update(deltaTime: delta, world: world, viewMaps: viewMaps, scene: nil)
        multiplayer.interpolate(currentTime: CACurrentMediaTime())
        frameCount += 1
        if frameCount <= 10 || frameCount % 60 == 0, let player = viewMaps.player {
            let pos = player.position
            let fwd = full.forward
            NSLog("[WB-R] f=\(frameCount) pos=(%.2f,%.2f,%.2f) fwd=\(fwd) yaw=%.2f soldier=\(viewMaps.soldier != nil)", pos.x, pos.y, pos.z, fwd, world.entities[playerSystem.localPlayerId]?.getComponent(PlayerComponentState.self)?.yaw ?? 0)
        }
    }
    var frameCount = 0

    // Triangle-accurate static collision for the map. The map is one merged
    // mesh, so box/convex shapes degenerate to its bounding box (players walk
    // on an invisible "ceiling"). generateStaticMesh gives real trimesh hits.
    private func addPerMeshCollision(to root: RealityKit.Entity) async {
        var stack: [RealityKit.Entity] = [root]
        var count = 0
        while let e = stack.popLast() {
            stack.append(contentsOf: e.children)
            guard let model = e.components[ModelComponent.self] else { continue }
            var shapes: [ShapeResource] = []
            if let shape = try? await ShapeResource.generateStaticMesh(from: model.mesh) {
                shapes.append(shape)
            }
            if !shapes.isEmpty {
                e.components.set(CollisionComponent(shapes: shapes))
                count += shapes.count
            }
        }
        NSLog("[WB-R] static-mesh collision shapes: \(count)")
    }

    // Roughness/metalness fix: removes "plastic wrap" gloss from USDZ materials
    private func fixMaterials(_ root: RealityKit.Entity) {
        for child in root.children {
            if var model = child.components[ModelComponent.self] {
                var newMats: [RealityKit.Material] = []
                for mat in model.materials {
                    if var pbr = mat as? PhysicallyBasedMaterial {
                        pbr.roughness = .init(floatLiteral: 0.85)
                        pbr.metallic = .init(floatLiteral: 0.0)
                        newMats.append(pbr)
                    } else {
                        newMats.append(mat)
                    }
                }
                model.materials = newMats
                child.components.set(model)
            }
            fixMaterials(child)
        }
    }

    private func addSkyDome(to parent: RealityKit.Entity) {
        let sky = ModelEntity(mesh: .generateSphere(radius: 400))
        var mat = UnlitMaterial(color: PlatformColor(red: 0.45, green: 0.70, blue: 0.95, alpha: 1))
        mat.faceCulling = .none
        sky.model?.materials = [mat]
        sky.name = "skyDome"
        parent.addChild(sky)
    }
}

struct RealityGameView: View {
    let username: String
    let roomID: String
    let selectedMap: String
    let selectedClass: String
    var networkManager: NetworkManager? = nil
    var gameVM: GameViewModel
    @StateObject private var coordinator = RealityCoordinator()
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RealityView { content in
                NSLog("[WB-R] RealityView make")
                coordinator.selectedClass = selectedClass
                coordinator.coordinatorUsername = username
                coordinator.coordinatorRoom = roomID
                coordinator.networkManager = networkManager
                coordinator.gameVM = gameVM
                await coordinator.setup(content)
                if let env = coordinator.skybox {
                    content.environment = .skybox(env)
                }
            }
            .ignoresSafeArea()
#if os(macOS)
            KeyCaptureView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.01)
#endif
            if !coordinator.ready {
                // Loading overlay: live RealityKit spinners visible through a
                // subtle dark veil; crossfades out when setup completes.
                VStack(spacing: 24) {
                    Spacer()
                    Text("WARBASE")
                        .font(.system(size: 56, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(10)
                    Text(coordinator.loadingStatus)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.9, green: 0.3, blue: 0.2)))
                        .scaleEffect(1.3)
                    Spacer()
                    Text("WASD move  •  Mouse look  •  Shift sprint  •  Space jump")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: coordinator.ready)
            } else if !focused {
                VStack {
                    Text("CLICK TO PLAY")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
                .onTapGesture {
                    focused = true
                    NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView)
                    InputManager.lockCursor()
                }
            }
        }
        .focusable()
        .focused($focused)
        .onAppear {
            NSLog("[WB-R] RealityGameView appear")
            focused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true; NSApp.activate(ignoringOtherApps: true) }
        }
        .onDisappear { InputManager.remove() }
        .onKeyPress(phases: .down) { press in
            let key = press.characters.lowercased()
            if key == "w" { InputManager.setForward(true); return .handled }
            if key == "a" { InputManager.setLeft(true); return .handled }
            if key == "s" { InputManager.setBackward(true); return .handled }
            if key == "d" { InputManager.setRight(true); return .handled }
            return .ignored
        }
        .onKeyPress(phases: .up) { press in
            let key = press.characters.lowercased()
            if key == "w" { InputManager.setForward(false); return .handled }
            if key == "a" { InputManager.setLeft(false); return .handled }
            if key == "s" { InputManager.setBackward(false); return .handled }
            if key == "d" { InputManager.setRight(false); return .handled }
            return .ignored
        }
    }
}
