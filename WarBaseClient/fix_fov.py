import os

path = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/ECS/Systems/PlayerMovementSystem.swift"
with open(path, 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "let currentFOV = camera.fieldOfView" in line:
        lines[i] = "            let currentFOV = Float(camNode.camera?.fieldOfView ?? CGFloat(BASE_FOV))\n"
    elif "camera.fieldOfView = currentFOV + (targetFOV - currentFOV) * CGFloat(FOV_LERP_SPEED * deltaTime)" in line:
        lines[i] = "            camNode.camera?.fieldOfView = CGFloat(currentFOV + (Float(targetFOV) - currentFOV) * FOV_LERP_SPEED * deltaTime)\n"

with open(path, 'w') as f:
    f.writelines(lines)

