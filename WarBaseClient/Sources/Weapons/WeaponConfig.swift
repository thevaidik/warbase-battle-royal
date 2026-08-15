import Foundation
import SceneKit


public struct WeaponConfig {
    public var damage: Float
    public var headshotMult: Float
    public var fireRate: Float
    public var magSize: Int
    public var reloadTime: Float
    
    public var baseSpread: Float
    public var bloomPerShot: Float
    public var maxSpread: Float
    public var bloomRecovery: Float
    
    public var recoilVertical: Float
    public var recoilHorizontal: Float
    public var recoilRecovery: Float
    
    public var adsFOV: Float
    public var adsTime: Float
    public var adsSpreadMult: Float
    public var adsRecoilMult: Float
    
    public var hipPosition: SCNVector3
    public var adsPosition: SCNVector3
    
    public var isAuto: Bool
}

public let WEAPON_CONFIGS: [String: WeaponConfig] = [
    "AK-47": WeaponConfig(
        damage: 34,
        headshotMult: 2.5,
        fireRate: 600,
        magSize: 30,
        reloadTime: 2.5,
        baseSpread: 1.5,
        bloomPerShot: 0.4,
        maxSpread: 5.0,
        bloomRecovery: 8.0,
        recoilVertical: 0.02,
        recoilHorizontal: 0.008,
        recoilRecovery: 6.0,
        adsFOV: 55,
        adsTime: 0.2,
        adsSpreadMult: 0.4,
        adsRecoilMult: 0.7,
        hipPosition: SCNVector3(0.3, -0.3, 0.6),
        adsPosition: SCNVector3(0, -0.15, 0.4),
        isAuto: true
    ),
    "Pistol": WeaponConfig(
        damage: 25,
        headshotMult: 3.0,
        fireRate: 400,
        magSize: 12,
        reloadTime: 1.5,
        baseSpread: 1.0,
        bloomPerShot: 0.8,
        maxSpread: 6.0,
        bloomRecovery: 12.0,
        recoilVertical: 0.04,
        recoilHorizontal: 0.005,
        recoilRecovery: 10.0,
        adsFOV: 65,
        adsTime: 0.12,
        adsSpreadMult: 0.2,
        adsRecoilMult: 0.5,
        hipPosition: SCNVector3(0.2, -0.2, 0.5),
        adsPosition: SCNVector3(0, -0.1, 0.35),
        isAuto: false
    ),
    "M2010": WeaponConfig(
        damage: 95,
        headshotMult: 2.5,
        fireRate: 45,
        magSize: 5,
        reloadTime: 3.2,
        baseSpread: 0.2,
        bloomPerShot: 2.0,
        maxSpread: 8.0,
        bloomRecovery: 5.0,
        recoilVertical: 0.08,
        recoilHorizontal: 0.015,
        recoilRecovery: 4.0,
        adsFOV: 25,
        adsTime: 0.3,
        adsSpreadMult: 0.05,
        adsRecoilMult: 0.3,
        hipPosition: SCNVector3(0.12, -0.15, 0.25),
        adsPosition: SCNVector3(0, -0.135, 0.35),
        isAuto: false
    )
]
