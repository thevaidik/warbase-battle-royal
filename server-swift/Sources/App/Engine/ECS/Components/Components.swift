import Foundation

// MARK: - Component Protocol
protocol ServerComponent: Sendable {}

// MARK: - Transform & Movement
struct TransformComponent: ServerComponent {
    var x: Float
    var y: Float
    var z: Float
    var heading: Float // Radians
    var targetX: Float?
    var targetZ: Float?
    var speed: Float
    
    init(x: Float = 0, y: Float = 0, z: Float = 0, heading: Float = 0, speed: Float = 15.0) {
        self.x = x
        self.y = y
        self.z = z
        self.heading = heading
        self.speed = speed
    }
}

// MARK: - Unit Identity & Hierarchy
enum Faction: String, Sendable, Codable {
    case bluefor = "BLUEFOR"
    case redfor = "REDFOR"
}

enum UnitType: String, Sendable, Codable {
    case mechInfantry = "MECH_INFANTRY"
    case armor = "ARMORED"
    case tubeArtillery = "TUBE_ARTILLERY"
    case rocketArtillery = "ROCKET_ARTILLERY"
    case shorad = "SHORAD"
    case ewCompany = "EW_COMPANY"
    case droneRecon = "DRONE_RECON"
    case fpvPlatoon = "FPV_PLATOON"
    case logistics = "LOGISTICS"
}

enum Echelon: String, Sendable, Codable {
    case brigade = "BRIGADE"
    case battalion = "BATTALION"
    case company = "COMPANY"
    case battery = "BATTERY"
    case platoon = "PLATOON"
}

struct UnitIdentityComponent: ServerComponent {
    var id: String
    var name: String
    var callsign: String
    var faction: Faction
    var unitType: UnitType
    var echelon: Echelon
    var parentId: String?
    
    init(id: String, name: String, callsign: String, faction: Faction, unitType: UnitType, echelon: Echelon, parentId: String? = nil) {
        self.id = id
        self.name = name
        self.callsign = callsign
        self.faction = faction
        self.unitType = unitType
        self.echelon = echelon
        self.parentId = parentId
    }
}

// MARK: - Combat & Protection
enum UnitStatus: String, Sendable, Codable {
    case idle = "IDLE"
    case moving = "MOVING"
    case firing = "FIRING"
    case entrenching = "ENTRENCHING"
    case engaged = "ENGAGED"
    case suppressed = "SUPPRESSED"
    case retreating = "RETREATING"
    case destroyed = "DESTROYED"
}

struct CombatStatsComponent: ServerComponent {
    var health: Float // 0.0 to 100.0
    var maxHealth: Float
    var personnel: Int32
    var vehicles: Int32
    var armorRating: Float // RHA equivalent mm
    var softAttack: Float
    var hardAttack: Float
    var suppression: Float // 0.0 to 1.0
    var morale: Float // 0.0 to 1.0
    var entrenchmentLevel: Int32 // 0, 1, 2, 3
    var status: UnitStatus
    var activeTargetId: String?
    
    init(health: Float = 100.0, personnel: Int32 = 450, vehicles: Int32 = 32, armorRating: Float = 50.0, softAttack: Float = 35.0, hardAttack: Float = 25.0) {
        self.health = health
        self.maxHealth = health
        self.personnel = personnel
        self.vehicles = vehicles
        self.armorRating = armorRating
        self.softAttack = softAttack
        self.hardAttack = hardAttack
        self.suppression = 0.0
        self.morale = 1.0
        self.entrenchmentLevel = 0
        self.status = .idle
    }
}

// MARK: - Sensors & Reconnaissance
struct SensorComponent: ServerComponent {
    var opticalRange: Float // meters
    var thermalRange: Float // meters
    var radarRange: Float // meters
    var rcsProfile: Float // Radar Cross Section
    var isLaserDesignating: Bool
    var laserTargetId: String?
    
    init(opticalRange: Float = 3000.0, thermalRange: Float = 2000.0, radarRange: Float = 0.0, rcsProfile: Float = 10.0) {
        self.opticalRange = opticalRange
        self.thermalRange = thermalRange
        self.radarRange = radarRange
        self.rcsProfile = rcsProfile
        self.isLaserDesignating = false
    }
}

// MARK: - Electronic Warfare (EW)
struct ElectronicWarfareComponent: ServerComponent {
    var jammingRadius: Float // meters
    var powerDbm: Float
    var isTransmitting: Bool
    var gpsDenied: Bool
    
    init(jammingRadius: Float = 5000.0, powerDbm: Float = 80.0, isTransmitting: Bool = true, gpsDenied: Bool = true) {
        self.jammingRadius = jammingRadius
        self.powerDbm = powerDbm
        self.isTransmitting = isTransmitting
        self.gpsDenied = gpsDenied
    }
}

// MARK: - Artillery Battery
struct FireMission: Sendable {
    var missionId: String
    var targetX: Float
    var targetY: Float
    var targetZ: Float
    var munitionType: String // "HE", "AIRBURST", "PRECISION_GUIDED", "CLUSTER"
    var totalRounds: Int32
    var roundsFired: Int32
    var flightTimeSec: Float
    var timeToImpact: Float
    var dispersionCep: Float
}

struct ArtilleryBatteryComponent: ServerComponent {
    var caliberMm: Int32 // 155, 152, 227 (HIMARS)
    var maxRangeM: Float
    var reloadTimeSec: Float
    var dispersionCepM: Float
    var lastFireTimestamp: Double
    var activeMissions: [FireMission]
    
    init(caliberMm: Int32 = 155, maxRangeM: Float = 24000.0, reloadTimeSec: Float = 8.0, dispersionCepM: Float = 25.0) {
        self.caliberMm = caliberMm
        self.maxRangeM = maxRangeM
        self.reloadTimeSec = reloadTimeSec
        self.dispersionCepM = dispersionCepM
        self.lastFireTimestamp = 0
        self.activeMissions = []
    }
}

// MARK: - Drone Platform
enum DroneType: String, Sendable, Codable {
    case reconQuadcopter = "RECON_QUADCOPTER"
    case reconFixedWing = "RECON_FIXED_WING"
    case fpvKamikaze = "FPV_KAMIKAZE"
    case heavyBomber = "HEAVY_BOMBER"
}

struct DronePlatformComponent: ServerComponent {
    var droneType: DroneType
    var batteryPercent: Float // 0.0 to 100.0
    var signalQuality: Float // 0.0 to 1.0
    var payloadArmorPenetration: Float // mm RHA
    var payloadDamage: Float
    var isLaserDesignating: Bool
    var targetUnitId: String?
    var isDiving: Bool
    
    init(droneType: DroneType = .reconQuadcopter, payloadPenetration: Float = 0.0, payloadDamage: Float = 0.0) {
        self.droneType = droneType
        self.batteryPercent = 100.0
        self.signalQuality = 1.0
        self.payloadArmorPenetration = payloadPenetration
        self.payloadDamage = payloadDamage
        self.isLaserDesignating = false
        self.isDiving = false
    }
}

// MARK: - Supply & Logistics
struct SupplyComponent: ServerComponent {
    var ammoLevel: Float // 0.0 to 1.0
    var fuelLevel: Float // 0.0 to 1.0
    var batteryLevel: Float // 0.0 to 1.0
    var resupplyRatePerSec: Float
    
    init(ammo: Float = 1.0, fuel: Float = 1.0, battery: Float = 1.0, resupplyRate: Float = 0.05) {
        self.ammoLevel = ammo
        self.fuelLevel = fuel
        self.batteryLevel = battery
        self.resupplyRatePerSec = resupplyRate
    }
}

// MARK: - Orders
struct StrategicOrder: Sendable {
    var orderId: String
    var orderType: String // "MOVE", "ASSAULT", "ENTRENCH", "FIRE_MISSION", "LAUNCH_DRONE", "ACTIVATE_EW", "RESUPPLY", "LAY_MINES"
    var targetX: Float
    var targetY: Float
    var targetZ: Float
    var targetUnitId: String?
    var munitionType: String?
    var roundsCount: Int32
    var stance: String
}

struct OrderQueueComponent: ServerComponent {
    var orders: [StrategicOrder]
    
    init() {
        self.orders = []
    }
}
