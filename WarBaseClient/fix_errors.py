import os
import re

files_with_platform_color = [
    "Weapons/AK47Builder.swift",
    "Weapons/M2010Builder.swift",
    "Weapons/PistolBuilder.swift",
    "Weapons/GrenadeSystem.swift",
    "Weapons/WeaponConfig.swift",
    "ECS/Systems/DecalSystem.swift",
    "ECS/Systems/ImpactSystem.swift",
    "ECS/Systems/PlayerSystem.swift",
    "ECS/Systems/TracerSystem.swift"
]

base_dir = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/"

platform_color_pattern = re.compile(
    r"#if canImport\(UIKit\)\nimport UIKit\ntypealias PlatformColor = UIColor\n#else\nimport AppKit\ntypealias PlatformColor = NSColor\n#endif\n?",
    re.MULTILINE
)

for f in files_with_platform_color:
    path = os.path.join(base_dir, f)
    if os.path.exists(path):
        with open(path, 'r') as file:
            content = file.read()
        
        new_content = platform_color_pattern.sub('', content)
        if new_content != content:
            with open(path, 'w') as file:
                file.write(new_content)
            print(f"Removed PlatformColor from {f}")

network_manager_path = os.path.join(base_dir, "Network/NetworkManager.swift")
if os.path.exists(network_manager_path):
    with open(network_manager_path, 'r') as file:
        content = file.read()

    # Remove Warbase_ServerMessage struct
    content = re.sub(r'public struct Warbase_ServerMessage \{.*?\}\n', '', content, flags=re.DOTALL)
    # Remove Warbase_ClientEvent struct
    content = re.sub(r'public struct Warbase_ClientEvent \{.*?\}\n', '', content, flags=re.DOTALL)
    
    with open(network_manager_path, 'w') as file:
        file.write(content)
    print("Removed duplicate structs from NetworkManager.swift")

# Rename PlayerState -> LocalPlayerState in Components
components_path = os.path.join(base_dir, "ECS/Components.swift")
if os.path.exists(components_path):
    with open(components_path, 'r') as file:
        content = file.read()
    
    content = re.sub(r'\bstruct PlayerState\b', 'struct LocalPlayerState', content)
    
    with open(components_path, 'w') as file:
        file.write(content)
    print("Renamed PlayerState in Components.swift")

# Rename PlayerState -> LocalPlayerState in MultiplayerEntities.swift
multiplayer_path = os.path.join(base_dir, "Network/MultiplayerEntities.swift")
if os.path.exists(multiplayer_path):
    with open(multiplayer_path, 'r') as file:
        content = file.read()
    
    content = re.sub(r'\bPlayerState\b', 'LocalPlayerState', content)
    
    with open(multiplayer_path, 'w') as file:
        file.write(content)
    print("Renamed PlayerState in MultiplayerEntities.swift")

# Rename PlayerState -> LocalPlayerState in NetworkManager.swift
if os.path.exists(network_manager_path):
    with open(network_manager_path, 'r') as file:
        content = file.read()
    
    content = re.sub(r'\bPlayerState\b', 'LocalPlayerState', content)
    
    with open(network_manager_path, 'w') as file:
        file.write(content)
    print("Renamed PlayerState in NetworkManager.swift")

