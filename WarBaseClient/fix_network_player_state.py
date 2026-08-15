import os
import re

base_dir = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/"

network_player_state_code = """
public struct NetworkPlayerState {
    public var id: String
    public var x: Float
    public var y: Float
    public var z: Float
    public var rx: Float
    public var ry: Float
    public var rz: Float
    public var rw: Float
    public var anim: String
    public var health: Float
    public var kills: Int
    public var deaths: Int
    public var isDead: Bool
    public var platformId: String
    public var ping: Int
    public var weaponId: String
    public var team: String
}
"""

network_manager_path = os.path.join(base_dir, "Network/NetworkManager.swift")
with open(network_manager_path, 'r') as file:
    content = file.read()

# Add the struct after imports
content = re.sub(r'(import Combine\n)', r'\1' + network_player_state_code + '\n', content)

# Replace Warbase_PlayerState with NetworkPlayerState
content = re.sub(r'\bWarbase_PlayerState\b', 'NetworkPlayerState', content)

with open(network_manager_path, 'w') as file:
    file.write(content)


multiplayer_path = os.path.join(base_dir, "Network/MultiplayerEntities.swift")
with open(multiplayer_path, 'r') as file:
    content = file.read()

# Replace Warbase_PlayerState with NetworkPlayerState
content = re.sub(r'\bWarbase_PlayerState\b', 'NetworkPlayerState', content)

with open(multiplayer_path, 'w') as file:
    file.write(content)

