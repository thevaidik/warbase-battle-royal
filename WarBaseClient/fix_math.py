import os

path = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/ECS/Systems/DecalSystem.swift"
with open(path, 'r') as f:
    text = f.read()

text = text.replace("return SCNVector3(vector.x * CGFloat(scalar), vector.y * CGFloat(scalar), vector.z * CGFloat(scalar))",
                    "return SCNVector3(Float(vector.x) * scalar, Float(vector.y) * scalar, Float(vector.z) * scalar)")

with open(path, 'w') as f:
    f.write(text)

