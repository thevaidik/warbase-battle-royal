import Foundation
import ModelIO

let url = URL(fileURLWithPath: "/Users/vaidik/Developer/WarBase /client/public/maps/low_poly_industrial_zone.glb")
let asset = MDLAsset(url: url)
print("Asset loaded with \(asset.count) objects")
if asset.count > 0 {
    let outUrl = URL(fileURLWithPath: "/tmp/test_swift_export.usdz")
    try! asset.export(to: outUrl)
    print("Exported successfully")
} else {
    print("Failed to load GLB")
}
