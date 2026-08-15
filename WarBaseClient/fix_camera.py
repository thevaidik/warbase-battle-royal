import os
import re

base_dir = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/"

view_maps = os.path.join(base_dir, "ECS/ViewMaps.swift")
with open(view_maps, 'r') as f:
    content = f.read()
content = content.replace("public var entityCameras: [Int: SCNCamera] = [:]", "public var entityCameras: [Int: SCNNode] = [:]")
with open(view_maps, 'w') as f:
    f.write(content)

player_system = os.path.join(base_dir, "ECS/Systems/PlayerSystem.swift")
with open(player_system, 'r') as f:
    content = f.read()
content = content.replace("viewMaps.entityCameras[id] = camera", "viewMaps.entityCameras[id] = camNode")
with open(player_system, 'w') as f:
    f.write(content)

player_movement = os.path.join(base_dir, "ECS/Systems/PlayerMovementSystem.swift")
with open(player_movement, 'r') as f:
    content = f.read()

# Fix the camera parent issue
content = content.replace("let camera = viewMaps.entityCameras[id] else {", "let camNode = viewMaps.entityCameras[id] else {")
content = content.replace("if let camNode = viewMaps.entityCameras[id]?.parent {", "if let camNode = viewMaps.entityCameras[id] {")
content = content.replace("camera.fieldOfView = CGFloat(targetFOV)", "camNode.camera?.fieldOfView = CGFloat(targetFOV)")

# Fix the CGFloat vs Float assignments
content = re.sub(r'currentVel\.x = CGFloat\(applyAccelDecel\(Float\(currentVel\.x\), targetVelocityX, deltaTime\)\)',
                 r'currentVel.x = applyAccelDecel(Float(currentVel.x), targetVelocityX, deltaTime)', content)
content = re.sub(r'currentVel\.z = CGFloat\(applyAccelDecel\(Float\(currentVel\.z\), targetVelocityZ, deltaTime\)\)',
                 r'currentVel.z = applyAccelDecel(Float(currentVel.z), targetVelocityZ, deltaTime)', content)
content = content.replace("currentVel.y = CGFloat(JUMP_IMPULSE)", "currentVel.y = Float(JUMP_IMPULSE)")
content = content.replace("camNode.position.y = CGFloat(newCamY)", "camNode.position.y = Float(newCamY)")

# Fix binary operator '*' cannot be applied to operands of type 'Duration' and 'Float'
# Wait, I need to see what Duration is here
with open(player_movement, 'w') as f:
    f.write(content)

