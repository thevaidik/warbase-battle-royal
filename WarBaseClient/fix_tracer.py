import os

path = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/ECS/Systems/TracerSystem.swift"
with open(path, 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "tracers[i].node.position = SCNVector3(" in line:
        lines[i] = """                    let nx = Float(start.x) + Float(dir.x) * p
                    let ny = Float(start.y) + Float(dir.y) * p
                    let nz = Float(start.z) + Float(dir.z) * p
                    tracers[i].node.position = SCNVector3(nx, ny, nz)
"""
        lines[i+1] = ""
        lines[i+2] = ""
        lines[i+3] = ""
        lines[i+4] = ""

with open(path, 'w') as f:
    f.writelines(lines)

