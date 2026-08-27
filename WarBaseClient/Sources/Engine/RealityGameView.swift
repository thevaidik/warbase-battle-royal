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
    var serverHost: String = "warbase.nxtlap.com"
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
    private var sceneEntities: [RealityKit.Entity] = []  // sun/ibl/floor/map for teardown

    func setup<C>(_ content: C) async where C: RealityViewContentProtocol {
        NSLog("[WB-R] RealityCoordinator setup start")
        buildLoadingScene(content)
        playerSystem = RealityPlayerSystem(world: world, viewMaps: viewMaps)
        movementSystem = RealityPlayerMovementSystem()
        movementSystem.spawnPoint = [0,2,0]

        loadingStatus = "LOADING ENVIRONMENT..."
        // RealityKit-native noon: HDR IBL (true reflections) + crisp sun + even ambient (no hotspot)
        if let env = try? await EnvironmentResource.load(named: "venice_sunset_1k") {
            skybox = env
            let ibl = RealityKit.Entity()
            ibl.name = "imageBasedLight"
            // 1.1 punchy but not blown; IBL gives HDR reflections on metal
            ibl.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 1.1))
            content.add(ibl)
            sceneEntities.append(ibl)
        }
        let sun = DirectionalLight()
        sun.name = "sun"
        // 5000 noon warm like industrial; 160 maxDistance covers arena
        sun.light = DirectionalLightComponent(color: .init(red: 1.0, green: 0.96, blue: 0.88, alpha: 1), intensity: 5000)
        sun.shadow = DirectionalLightComponent.Shadow(shadowProjection: .automatic(maximumDistance: 160), depthBias: 0.005)
        sun.position = [60, 80, 30]
        sun.look(at: .zero, from: [60, 80, 30], relativeTo: nil)
        content.add(sun)
        sceneEntities.append(sun)
        // Even ambient via IBL is enough — keep very soft fill only for under-bridge
        let fill = RealityKit.Entity()
        fill.name = "ambientFill"
        fill.components.set(PointLightComponent(color: .init(red: 1, green: 0.97, blue: 0.95, alpha: 1), intensity: 250, attenuationRadius: 220))
        fill.position = [0, 18, 0]
        content.add(fill)
        sceneEntities.append(fill)

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
                sceneEntities.append(map)
            }
        }
        let floor = RealityKit.Entity()
        floor.name = "floorCollision"
        floor.position.y = mapFloorY
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: 2000, height: 1, depth: 2000)]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.9, restitution: 0), mode: .static))
        content.add(floor)
        sceneEntities.append(floor)
        viewMaps.floor = floor

        // Defer one frame so floor.scene is non-nil (was nil immediately after content.add)
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Raycast straight down from high above origin to land on real ground
        if let scene = floor.scene ?? viewMaps.player?.scene {
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
        // Sky is HDR skybox from content.environment — no flat dome (was washing IBL reflections)
        // firm H6: ESC -> pause (was never wired)
        InputManager.onPauseToggle = { [weak self] in
            DispatchQueue.main.async {
                self?.gameVM?.showPauseMenu.toggle()
                if let isOpen = self?.gameVM?.showPauseMenu {
                    InputManager.setPauseMenuActive(isOpen)
                    if isOpen { InputManager.unlockCursor() } else { InputManager.lockCursor() }
                }
            }
        }
        if let net = networkManager {
            let username = coordinatorUsername
            let room = coordinatorRoom
            let rawHost = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
#if DEBUG
            let host = rawHost.isEmpty ? (UserDefaults.standard.string(forKey: "warbase_host") ?? "warbase.nxtlap.com") : rawHost
#else
            let host = "warbase.nxtlap.com"
#endif
            net.connect(username: username, room: room, host: host)
            // Chain callbacks so ContentView's GameViewModel wiring isn't lost (was overwritten)
            let prevHit = net.onHitConfirmed
            let prevKill = net.onKillConfirmed
            net.onHitConfirmed = { [weak self] a, b in
                prevHit?(a, b)
                DispatchQueue.main.async { self?.gameVM?.crosshairColor = .red; DispatchQueue.main.asyncAfter(deadline: .now()+0.1) { self?.gameVM?.crosshairColor = .white } }
            }
            net.onKillConfirmed = { [weak self] targetId in
                prevKill?(targetId)
                DispatchQueue.main.async { self?.gameVM?.showKillFeed = true; self?.gameVM?.killFeedText = "KILLED \(targetId)" }
            }
            // Remote fire: mirror web triggerFire() — tracer + impact + flash
            net.onFireReceived = { [weak self] shooterId, origin, hit, normal, hitWall in
                guard let self else { return }
                Task { @MainActor in
                    self.multiplayer.triggerFire(id: shooterId, origin: origin, hitPoint: hit, normal: normal, hitWall: hitWall, content: content, tracer: self.tracerSystem, impact: self.impactSystem, decal: self.decalSystem)
                }
            }
            let prevRespawn = net.onRespawn
            net.onRespawn = { [weak self] x, y, z in
                prevRespawn?(x, y, z)
                guard let self else { return }
                Task { @MainActor in
                    if let pl = self.viewMaps.player {
                        pl.position = SIMD3<Float>(x, y, z)
                        var m = pl.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                        m.linearVelocity = .zero; m.angularVelocity = .zero; pl.components.set(m)
                    }
                    if let eid = self.playerSystem.localPlayerId as Int?, let ent = self.world.entities[eid], var ps = ent.getComponent(PlayerComponentState.self) {
                        ps.isDead = false; ent.addComponent(ps)
                    }
                    self.movementSystem.spawnPoint = SIMD3<Float>(x, y, z)
                    self.gameVM?.isDead = false; self.gameVM?.health = 100
                }
            }
            net.onGrenadeReceived = { [weak self] shooterId, pos, vel in
                guard let self else { return }
                Task { @MainActor in
                    // grenade visuals: spawn at pos with vel; reuse local grenade path
                    if let sc = self.viewMaps.player?.scene {
                        // find a content-like handle via scene; fallback to tracer scene
                        let dummy: Any = content
                        if let c = dummy as? any _RealityKit_SwiftUI.RealityViewContentProtocol {
                            // GrenadeSystem needs content; use stored content handle via closure capture
                            let g = RealityGrenadeSystem()
                            g.throwGrenade(position: SIMD3<Float>(pos[0], pos[1], pos[2]), direction: SIMD3<Float>(vel[0], vel[1], vel[2]), content: c)
                        }
                    }
                }
            }
            net.onStateReceived = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    for (id, st) in state.players where id.lowercased() != username.lowercased() && self.multiplayer.players[id] == nil {
                        let mesh = await self.multiplayer.spawn(id: id, state: st, viewMaps: self.viewMaps)
                        content.add(mesh)
                    }
                    self.multiplayer.updateNetworkState(gameState: state, localUsername: username)
                    // Local HUD health/death/ping + ECS isDead (was missing)
                    if let me = state.players[username] {
                        self.gameVM?.setHealth(Int(me.health))
                        if self.gameVM?.isDead != me.isDead { self.gameVM?.setDead(me.isDead) }
                        self.gameVM?.setPing(Int(me.ping))
                        // sync ECS isDead so movement/weapon freeze
                        if let eid = self.playerSystem.localPlayerId as Int?, let ent = self.world.entities[eid], var ps = ent.getComponent(PlayerComponentState.self) {
                            if ps.isDead != me.isDead {
                                ps.isDead = me.isDead
                                ent.addComponent(ps)
                                if me.isDead {
                                    self.gameVM?.respawnTime = 3
                                } else {
                                    self.gameVM?.respawnTime = 3
                                }
                            }
                        } else if me.isDead && self.gameVM?.respawnTime == 3 {
                            self.gameVM?.respawnTime = 3
                        }
                    }
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

    func teardown() {
        for sub in subs { sub.cancel() }
        subs.removeAll()
        for e in sceneEntities { e.removeFromParent() }
        sceneEntities.removeAll()
        for e in loadingSpinners { e.removeFromParent() }
        loadingSpinners.removeAll()
        viewMaps.clearAll()
        world.clearAll()
        // reset lerp buffers
        multiplayer.players.removeAll()
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
            // TPS: muzzle world = RightHand bone + forward (like web muzzlePoint parented to RightHand)
            let muzzleWorld: SIMD3<Float> = { @MainActor in
                // inline hand lookup - MainActor isolated, avoid nested nonisolated closure
                var handNode: RealityKit.Entity? = nil
                if let sol = viewMaps.soldier {
                    for name in ["RightHand","mixamorig:RightHand"] {
                        var q: [RealityKit.Entity] = [sol]
                        var found: RealityKit.Entity? = nil
                        while !q.isEmpty { let e = q.removeFirst(); if e.name == name { found = e; break }; q.append(contentsOf: e.children) }
                        if found != nil { handNode = found; break }
                    }
                    if handNode == nil {
                        for name in ["RightHand","hand_r"] {
                            var q: [RealityKit.Entity] = [sol]
                            var found: RealityKit.Entity? = nil
                            while !q.isEmpty { let e = q.removeFirst(); if e.name.lowercased().contains(name.lowercased()) { found = e; break }; q.append(contentsOf: e.children) }
                            if found != nil { handNode = found; break }
                        }
                    }
                }
                if let hand = handNode {
                    let camFwd = normalize(-camEntity.orientation(relativeTo: nil).act(SIMD3<Float>(0,0,1)))
                    let mpos = hand.position(relativeTo: nil) + camFwd * 0.42 + SIMD3<Float>(0, -0.02, 0)
                    if frameCount % 120 == 0 { NSLog("[WB-R] MUZZLE hand=%@ cam=%@ muzzle=%@", "\(hand.position(relativeTo: nil))", "\(camEntity.position(relativeTo: nil))", "\(mpos)") }
                    return mpos
                }
                // hand not found — try weapon tip (chest holder, still on body), then player
                let candidates = [viewMaps.weaponAK, viewMaps.weaponM2010, viewMaps.weaponPistol].compactMap { $0 }
                if let w = candidates.first(where: { $0.isEnabled }) ?? candidates.first {
                    let tip: SIMD3<Float>
                    if w.name == "ak47" { tip = [0, 0.1, 3.3] }
                    else if w.name == "m2010" { tip = [0, 0.045, 1.28] }
                    else if w.name == "pistol" { tip = [0, 0.03, 0.25] }
                    else { tip = [0, 0, 0.6] }
                    let mpos = w.convert(position: tip, to: nil)
                    if frameCount % 120 == 0 { NSLog("[WB-R] MUZZLE weapon=%@ muzzle=%@", "\(w.name)", "\(mpos)") }
                    return mpos
                }
                if let pl = viewMaps.player {
                    let camFwd = normalize(-camEntity.orientation(relativeTo: nil).act(SIMD3<Float>(0,0,1)))
                    let mpos = pl.position(relativeTo: nil) + SIMD3<Float>(0.25, 1.15, 0.25) + camFwd * 0.35
                    if frameCount % 120 == 0 { NSLog("[WB-R] MUZZLE fallback player=%@ cam=%@ muzzle=%@", "\(pl.position)", "\(camEntity.position(relativeTo: nil))", "\(mpos)") }
                    return mpos
                }
                // absolute last resort — still offset from body, not lens
                return (viewMaps.player?.position ?? camEntity.position(relativeTo: nil)) + SIMD3<Float>(0.3, 1.15, 0)
            }()

                        weaponSystem.update(input: full, entity: e, weaponState: &wep, recoilState: &recoil, swayState: &sway, time: t, dt: delta, swayRoot: swayRoot, camera: camEntity, scene: scene, tracer: tracerSystem, impact: impactSystem, decal: decalSystem, network: networkManager, content: content, isAssault: isAssault, muzzlePos: muzzleWorld)
            // Grenade throw (was completely missing — button did nothing)
            if full.grenade, let pl = viewMaps.player {
                let camFwd = normalize(-camEntity.orientation(relativeTo: nil).act(SIMD3<Float>(0,0,1)))
                // origin from hand/body, not camera (like muzzle)
                let origin: SIMD3<Float> = {
                    if let sol = viewMaps.soldier {
                        var q: [RealityKit.Entity] = [sol]
                        var hand: RealityKit.Entity? = nil
                        while !q.isEmpty { let ent = q.removeFirst(); if ent.name == "RightHand" || ent.name == "mixamorig:RightHand" { hand = ent; break }; q.append(contentsOf: ent.children) }
                        if let h = hand { return h.position(relativeTo: nil) + camFwd * 0.35 }
                    }
                    return pl.position(relativeTo: nil) + SIMD3<Float>(0.3, 1.15, 0) + camFwd * 0.35
                }()
                let gsys = RealityGrenadeSystem()
                gsys.throwGrenade(position: origin, direction: camFwd, content: content)
                networkManager?.sendGrenade(position: [origin.x, origin.y, origin.z], velocity: [camFwd.x*8, camFwd.y*8+5, camFwd.z*8])
            }
            e.addComponent(wep); e.addComponent(recoil); e.addComponent(sway)
            // HUD sync (firm fix: was never wired)
            gameVM?.setAmmo(wep.currentAmmo)
            gameVM?.weaponName = wep.activeWeaponIndex == 1 ? "Pistol" : (isAssault ? "AK-47" : "M2010")
            gameVM?.maxAmmo = wep.activeWeaponIndex == 1 ? 12 : (isAssault ? 30 : 5)
            let isSniper = (!isAssault && wep.activeWeaponIndex == 0)
            gameVM?.isScoped = isSniper && wep.adsProgress > 0.5
            let isAssaultSend = isAssault
            let snapInput = full; let snapWep = wep
            if CACurrentMediaTime() - lastTime >= 0.016 { lastTime = CACurrentMediaTime(); DispatchQueue.main.async { [weak self] in self?.sendNetworkState(input: snapInput, weaponState: snapWep, isAssault: isAssaultSend) } }
        }
        multiplayer.interpolate(currentTime: CACurrentMediaTime(), viewMaps: viewMaps)
        // Respawn countdown (web: 3s then RespawnRequest)
        if let vm = gameVM, vm.isDead {
            // simple frame-based 1s tick
            if frameCount % 60 == 0 && vm.respawnTime > 0 {
                vm.respawnTime -= 1
                if vm.respawnTime <= 0 {
                    networkManager?.sendRespawnRequest()
                    vm.respawnTime = 3
                }
            }
        }
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
        multiplayer.interpolate(currentTime: CACurrentMediaTime(), viewMaps: viewMaps)
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
        // Collect first, then parallelize mesh generation
        var meshes: [RealityKit.Entity] = []
        var stack: [RealityKit.Entity] = [root]
        while let e = stack.popLast() {
            stack.append(contentsOf: e.children)
            if e.components[ModelComponent.self] != nil { meshes.append(e) }
        }
        // Capture meshes nonisolated; avoid actor-isolated components capture in TaskGroup
        let meshCopies: [(RealityKit.Entity, MeshResource)] = meshes.compactMap { e in
            guard let m = e.components[ModelComponent.self]?.mesh else { return nil }
            return (e, m)
        }
        let results = await withTaskGroup(of: (RealityKit.Entity, ShapeResource?).self) { group in
            for (e, m) in meshCopies {
                group.addTask {
                    let shape = try? await ShapeResource.generateStaticMesh(from: m)
                    return (e, shape)
                }
            }
            var out: [(RealityKit.Entity, ShapeResource?)] = []
            for await r in group { out.append(r) }
            return out
        }
        var count = 0
        for (e, shape) in results where shape != nil {
            e.components.set(CollisionComponent(shapes: [shape!]))
            e.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.9, restitution: 0), mode: .static))
            count += 1
        }
        NSLog("[WB-R] static-mesh collision shapes: \(count) (parallel)")
    }

    // Matte concrete fix: USDZ comes mirror (metallic 0.8 rough 0.2) + IBL = plastic wrap
    // Best RealityKit can do: PBR rough 0.95 metal 0.0 clearcoat 0, SimpleMaterial specular 0.1
    private func fixMaterials(_ root: RealityKit.Entity) {
        for child in root.children {
            if var model = child.components[ModelComponent.self] {
                var newMats: [RealityKit.Material] = []
                for mat in model.materials {
                    if var pbr = mat as? PhysicallyBasedMaterial {
                        pbr.roughness = .init(floatLiteral: 0.95)
                        pbr.metallic = .init(floatLiteral: 0.0)
                        pbr.clearcoat = .init(floatLiteral: 0.0)
                        // keep baseColor, kill mirror reflections from IBL
                        newMats.append(pbr)
                    } else if var simple = mat as? SimpleMaterial {
                        simple.roughness = .init(floatLiteral: 0.92)
                        simple.metallic = .init(floatLiteral: 0.0)
                        newMats.append(simple)
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
    let serverHost: String
    var networkManager: NetworkManager? = nil
    var gameVM: GameViewModel
    @StateObject private var coordinator = RealityCoordinator()
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            RealityView { content in
                NSLog("[WB-R] RealityView make")
                coordinator.selectedClass = selectedClass
                coordinator.serverHost = serverHost
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
        .onDisappear { coordinator.teardown(); InputManager.remove() }
        // firm H6: WASD handled exclusively by InputManager.install monitor — remove duplicate SwiftUI handler
    }
}
