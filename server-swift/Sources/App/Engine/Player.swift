import Foundation

final class Player: @unchecked Sendable {
    let id: String
    var state: Warbase_PlayerState
    var activeWeapon: WeaponConfig
    var ammoCount: Int
    var ammoStore: [String: Int]
    var lastShotTime: ContinuousClock.Instant
    var isReloading = false
    var reloadStart: ContinuousClock.Instant = .now
    var deathTime: ContinuousClock.Instant?

    init(id: String) {
        let w = Weapons["ak47"]!
        var store: [String:Int] = [:]
        for (k,v) in Weapons { store[k]=v.magSize }
        self.id = id
        var st = Warbase_PlayerState()
        st.health = 100; st.animation = "idle"; st.weaponID = "ak47"
        self.state = st; self.activeWeapon = w; self.ammoCount = w.magSize; self.ammoStore = store
        self.lastShotTime = .now - .seconds(3600)
    }

    enum ValidationError: Error, CustomStringConvertible {
        case msg(String)
        var description: String { switch self { case .msg(let m): return m } }
    }

    func validateAndApplyFire(now: ContinuousClock.Instant) throws {
        if state.isDead { throw ValidationError.msg("dead players cannot shoot") }
        if isReloading {
            if now >= reloadStart + activeWeapon.reloadTime {
                isReloading = false; ammoCount = activeWeapon.magSize; ammoStore[activeWeapon.id]=ammoCount
            } else { throw ValidationError.msg("cannot shoot while reloading") }
        }
        let minInterval = Duration.seconds(60) / activeWeapon.rpm
        let threshold = minInterval - .milliseconds(200) > .zero ? minInterval - .milliseconds(200) : .zero
        if now - lastShotTime < threshold { throw ValidationError.msg("firing rate exceeds limits") }
        if ammoCount <= 0 { throw ValidationError.msg("no ammo") }
        ammoCount -= 1; ammoStore[activeWeapon.id]=ammoCount; lastShotTime = now
    }

    func validateAndApplyReload(now: ContinuousClock.Instant) throws {
        if state.isDead { throw ValidationError.msg("dead players cannot reload") }
        if isReloading { throw ValidationError.msg("already reloading") }
        if ammoCount == activeWeapon.magSize { throw ValidationError.msg("magazine already full") }
        isReloading = true; reloadStart = now
    }

    func validateAndApplyHit(target: Player, clientDamage: Int) throws -> Bool {
        if state.isDead { throw ValidationError.msg("shooter is dead") }
        if target.state.isDead { throw ValidationError.msg("target is already dead") }
        if isReloading { throw ValidationError.msg("shooter was reloading") }
        if id == target.id { throw ValidationError.msg("cannot shoot yourself") }
        let maxDamage = Int(Double(activeWeapon.damage) * 3.0)
        if clientDamage <= 0 || clientDamage > maxDamage { throw ValidationError.msg("invalid damage") }
        target.state.health -= Int32(clientDamage)
        if target.state.health <= 0 {
            target.state.health = 0; target.state.isDead = true; target.state.deaths += 1; target.state.animation = "death"
            target.deathTime = .now; state.kills += 1; return true
        }
        return false
    }
}
