import os
import re

base_dir = "/Users/vaidik/Developer/WarBase /WarBaseClient/Sources/"

# Change Components.swift back to PlayerComponentState
components_path = os.path.join(base_dir, "ECS/Components.swift")
with open(components_path, 'r') as file:
    content = file.read()
content = re.sub(r'\bstruct LocalPlayerState\b', 'struct PlayerComponentState', content)
with open(components_path, 'w') as file:
    file.write(content)

# In PlayerSystem.swift, we need to change LocalPlayerState to PlayerComponentState
player_system_path = os.path.join(base_dir, "ECS/Systems/PlayerSystem.swift")
with open(player_system_path, 'r') as file:
    content = file.read()
content = re.sub(r'\bPlayerState\b', 'PlayerComponentState', content)
content = re.sub(r'\bLocalPlayerState\b', 'PlayerComponentState', content)
with open(player_system_path, 'w') as file:
    file.write(content)

# In NetworkManager.swift, we want to replace `struct LocalPlayerState { ... }` with nothing, and use Warbase_PlayerState.
network_manager_path = os.path.join(base_dir, "Network/NetworkManager.swift")
with open(network_manager_path, 'r') as file:
    content = file.read()
# Remove struct LocalPlayerState
content = re.sub(r'public struct LocalPlayerState \{.*?\}\n\n', '', content, flags=re.DOTALL)
# Replace LocalPlayerState with Warbase_PlayerState
content = re.sub(r'\bLocalPlayerState\b', 'Warbase_PlayerState', content)
with open(network_manager_path, 'w') as file:
    file.write(content)

# In MultiplayerEntities.swift, replace LocalPlayerState with Warbase_PlayerState
multiplayer_path = os.path.join(base_dir, "Network/MultiplayerEntities.swift")
with open(multiplayer_path, 'r') as file:
    content = file.read()
content = re.sub(r'\bLocalPlayerState\b', 'Warbase_PlayerState', content)
with open(multiplayer_path, 'w') as file:
    file.write(content)

