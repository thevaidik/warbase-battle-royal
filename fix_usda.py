import sys
import re

def fix_usda(input_file, output_file):
    with open(input_file, 'r') as f:
        content = f.read()

    # Step 1: Find all material definitions and their texture paths
    # Example:
    # def Material "Color"
    # {
    #     asset inputs:baseColorTexture = @Color_diffuse.png@
    
    # We want to map paths like </ROOT/Materials/MaterialName.inputs:baseColorTexture> to @texture.png@
    # But since we might not know ROOT, let's just map MaterialName.inputs:baseColorTexture to @texture.png@
    
    # Let's find all material names and their inputs
    # We will use regex to find: def Material "Name" ... { ... asset inputs:xxxTexture = @file.png@ ... }
    
    material_map = {}
    
    # Find all def Material blocks
    materials = re.findall(r'def Material "([^"]+)"\s*\{([^}]*?)(?=def NodeGraph)', content, re.DOTALL)
    for mat_name, mat_content in materials:
        textures = re.findall(r'asset inputs:(\w+Texture) = @([^@]+)@', mat_content)
        for tex_type, tex_file in textures:
            # We map this to the connection suffix:
            key = f"Materials/{mat_name}.inputs:{tex_type}"
            material_map[key] = tex_file

    # Step 2: Replace connections in shaders
    # asset inputs:file.connect = </low_poly_industrial_zone/Materials/Color.inputs:baseColorTexture>
    
    def replacer(match):
        full_path = match.group(1) # e.g. /low_poly_industrial_zone/Materials/Color.inputs:baseColorTexture
        # Find which key it matches
        for key, tex_file in material_map.items():
            if key in full_path:
                return f'asset inputs:file = @{tex_file}@'
        return match.group(0)
    
    new_content = re.sub(r'asset inputs:file\.connect = <([^>]+)>', replacer, content)
    
    # Some older parsers prefer just inputs:file instead of asset inputs:file
    # But we'll stick to asset inputs:file which SceneKit handles if not connected.

    # Also, we might need to fix normal maps, opacity maps, etc. 
    # But replacing file.connect should handle all of them since they all use UsdUVTexture

    with open(output_file, 'w') as f:
        f.write(new_content)
        
    print(f"Fixed {input_file}, mapped {len(material_map)} textures.")

if __name__ == "__main__":
    fix_usda(sys.argv[1], sys.argv[2])
