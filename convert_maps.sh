#!/bin/bash
set -e
MAPS_DIR="/Users/vaidik/Developer/WarBase /client/public/maps"
MODELS_DIR="/Users/vaidik/Developer/WarBase /client/public/models"
DEST_DIR="/Users/vaidik/Developer/WarBase /WarBaseClient/Sources"

mkdir -p /tmp/map_conversions

rm -f "$DEST_DIR"/*.usdz
rm -f "$DEST_DIR"/*.usd

convert_asset() {
    local src_dir=$1
    local src_file=$2
    local out_name=$3
    echo "Converting $src_file to $out_name..."
    local tmp_dir="/tmp/map_conversions/$out_name"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    usdextract "$src_dir/$src_file" -o "$tmp_dir"
    cd "$tmp_dir"
    
    # Apply SceneKit texture fix
    local usdc_file=$(ls *.usdc)
    local usda_file="${usdc_file%.*}.usda"
    usdcat "$usdc_file" -o "$usda_file"
    
    python3 "/Users/vaidik/Developer/WarBase /fix_usda.py" "$usda_file" "fixed_$usda_file"
    
    rm "$usdc_file"
    usdcat "fixed_$usda_file" -o "$usdc_file"
    
    usdzip "$out_name" *.usdc *.png || usdzip "$out_name" *.usdc
    cp "$out_name" "$DEST_DIR/"
}

convert_asset "$MAPS_DIR" "low_poly_industrial_zone.glb" "industrial.usdz"
convert_asset "$MAPS_DIR" "village_lowres.glb" "village.usdz"
convert_asset "$MAPS_DIR" "fps_shooter_game_arena_map_v3.glb" "arena.usdz"
convert_asset "$MAPS_DIR" "BLD_Ghost_city.glb" "ghost_city.usdz"

convert_asset "$MODELS_DIR" "AnimatedSoldier.glb" "AnimatedSoldier.usdz"

echo "Done!"
