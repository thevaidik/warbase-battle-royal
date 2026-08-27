import Foundation

struct WeaponConfig: Sendable {
    let id: String
    let damage: Int
    let rpm: Int
    let magSize: Int
    let reloadTime: Duration
}

let Weapons: [String: WeaponConfig] = [
    "ak47": WeaponConfig(id: "ak47", damage: 34, rpm: 600, magSize: 30, reloadTime: .milliseconds(2500)),
    "pistol": WeaponConfig(id: "pistol", damage: 25, rpm: 400, magSize: 12, reloadTime: .milliseconds(1500)),
    "m2010": WeaponConfig(id: "m2010", damage: 95, rpm: 45, magSize: 5, reloadTime: .milliseconds(3200)),
]
