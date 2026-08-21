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
    @Published var skybox: EnvironmentResource?

    func setup<C>(_ content: C) async where C: RealityViewContentProtocol {
        NSLog("[WB-R] RealityCoordinator setup start")
        playerSystem = RealityPlayerSystem(world: world, viewMaps: viewMaps)
        movementSystem = RealityPlayerMovementSystem()
        movementSystem.spawnPoint = [0,2,0]

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

        if let url = Bundle.main.url(forResource: "industrial", withExtension: "usdz") {
            if let map = try? await ModelEntity(contentsOf: url) {
                map.name = "industrial"
                fixMaterials(map)
                map.generateCollisionShapes(recursive: true)
                content.add(map)
            }
        }
        // Invisible floor (no white box)
        let floor = RealityKit.Entity()
        floor.name = "floorCollision"
        floor.position.y = -0.5
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: 200, height: 1, depth: 200)]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.9, restitution: 0), mode: .static))
        content.add(floor)

        let player = await playerSystem.initPlayer(spawnPosition: [0,2,0])
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
        _ = await MainActor.run { content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(delta: Float(event.deltaTime), content: content)
        } }
        if CommandLine.arguments.contains("--autodeploy") {
            NSLog("[WB-R] setup spawn [0,2,0] scheduling auto-W")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { InputManager.setForward(true); NSLog("[WB-R] W down") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { InputManager.setForward(false); NSLog("[WB-R] W up") }
        }
    }

    func tick<C>(delta: Float, content: C) where C: RealityViewContentProtocol {
        guard delta > 0, delta < 0.1 else { return }
        let (input, dx, dy) = inputManager.consume()
        var full = input
        full.mouseDeltaX = dx
        full.mouseDeltaY = dy
        if let e = world.entities[playerSystem.localPlayerId] {
            e.addComponent(full)
        }
        movementSystem.update(deltaTime: delta, world: world, viewMaps: viewMaps, scene: nil)
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
            var ws = RealityWeaponSystem()
            ws.update(input: full, entity: e, weaponState: &wep, recoilState: &recoil, swayState: &sway, time: t, dt: delta, swayRoot: swayRoot, camera: camEntity, scene: scene, tracer: RealityTracerSystem(), impact: RealityImpactSystem(), decal: RealityDecalSystem(), network: networkManager, content: content, isAssault: isAssault)
            e.addComponent(wep); e.addComponent(recoil); e.addComponent(sway)
            let isAssaultSend = isAssault
            let snapInput = full; let snapWep = wep
            if CACurrentMediaTime() - lastTime >= 0.033 { lastTime = CACurrentMediaTime(); DispatchQueue.main.async { [weak self] in self?.sendNetworkState(input: snapInput, weaponState: snapWep, isAssault: isAssaultSend) } }
        }
        multiplayer.interpolate(currentTime: CACurrentMediaTime())
        frameCount += 1
        if frameCount <= 10 || frameCount % 60 == 0, let player = viewMaps.player {
            let pos = player.position
            let fwd = full.forward
            NSLog("[WB-R] f=\(frameCount) pos=(%.2f,%.2f,%.2f) fwd=\(fwd) yaw=%.2f soldier=\(viewMaps.soldier != nil)", pos.x, pos.y, pos.z, fwd, world.entities[playerSystem.localPlayerId]?.getComponent(PlayerComponentState.self)?.yaw ?? 0)
        }
    }

    private func sendNetworkState(input: InputState, weaponState: WeaponState, isAssault: Bool) {
        guard let node = viewMaps.player else { return }
        let pos = node.position
        let rot = node.orientation
        let st = NetworkPlayerState(id: coordinatorUsername, x: Float(pos.x), y: Float(pos.y), z: Float(pos.z), rx: Float(rot.imag.x), ry: Float(rot.imag.y), rz: Float(rot.imag.z), rw: Float(rot.real), anim: "idle", health: 100, kills: 0, deaths: 0, isDead: false, platformId: "", ping: 0, weaponId: isAssault ? "ak47" : "m2010", team: "A")
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
            if !focused {
                VStack {
                    Text("CLICK TO PLAY  •  WASD to move  •  Mouse to look")
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
