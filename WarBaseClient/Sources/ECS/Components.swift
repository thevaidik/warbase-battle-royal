import Foundation

// MARK: - Component Protocol
public protocol Component {}

public struct Position: Component {
    public var x: Float = 0
    public var y: Float = 0
    public var z: Float = 0
    
    public init(x: Float = 0, y: Float = 0, z: Float = 0) {
        self.x = x; self.y = y; self.z = z
    }
}

public struct Rotation: Component {
    public var x: Float = 0
    public var y: Float = 0
    public var z: Float = 0
    public var w: Float = 1
    
    public init(x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 1) {
        self.x = x; self.y = y; self.z = z; self.w = w
    }
}

public struct Velocity: Component {
    public var x: Float = 0
    public var y: Float = 0
    public var z: Float = 0
    
    public init(x: Float = 0, y: Float = 0, z: Float = 0) {
        self.x = x; self.y = y; self.z = z
    }
}

public struct InputState: Component {
    public var forward: Bool = false
    public var backward: Bool = false
    public var left: Bool = false
    public var right: Bool = false
    public var jump: Bool = false
    public var crouch: Bool = false
    public var sprint: Bool = false
    public var fire: Bool = false
    public var ads: Bool = false
    public var reload: Bool = false
    public var weapon1: Bool = false
    public var weapon2: Bool = false
    public var grenade: Bool = false
    
    public var mouseDeltaX: Float = 0
    public var mouseDeltaY: Float = 0
    
    public init() {}
}

public struct PlayerComponentState: Component {
    public var isGrounded: Bool = false
    public var isCrouching: Bool = false
    public var isSprinting: Bool = false
    public var isDead: Bool = false
    
    public var jumpCooldownTimer: Float = 0
    public var coyoteTimer: Float = 0
    
    public var yaw: Float = 0
    public var pitch: Float = 0
    
    public init() {}
}

public struct WeaponState: Component {
    public var activeWeaponIndex: Int = 0
    public var currentAmmo: Int = 30  // AK-47 default mag; overwritten on weapon switch
    public var isReloading: Bool = false
    
    public var reloadTimer: Float = 0
    public var currentSpread: Float = 0
    public var lastFireTime: Float = 0
    public var adsProgress: Float = 0
    public var hasFiredThisClick: Bool = false
    
    public init() {}
}

public struct RecoilState: Component {
    public var rotationX: Float = 0
    public var rotationY: Float = 0
    public var velocityX: Float = 0
    public var velocityY: Float = 0
    
    public var kickbackZ: Float = 0
    public var kickbackRotX: Float = 0
    
    public init() {}
}

public struct SwayState: Component {
    public var swayX: Float = 0
    public var swayY: Float = 0
    public var walkBobTimer: Float = 0
    
    public init() {}
}
