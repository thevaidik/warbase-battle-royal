import {
    Scene,
    Vector3,
    PhysicsAggregate,
    PhysicsShapeType,
    ShadowGenerator,
    SceneLoader
} from "@babylonjs/core";

export class EnvironmentManager {
    private scene: Scene;
    private shadowGenerator: ShadowGenerator;
    private mapChoice: string;

    constructor(scene: Scene, shadowGenerator: ShadowGenerator, mapChoice: string = "original") {
        this.scene = scene;
        this.shadowGenerator = shadowGenerator;
        this.mapChoice = mapChoice;
    }

    public async init() {
        if (this.shadowGenerator) console.log("Shadow generator is active in Environment.");

        if (this.mapChoice === "industrial") {
            await this.loadGLBMap("low_poly_industrial_zone.glb");
        } else if (this.mapChoice === "village") {
            await this.loadGLBMap("village_lowres.glb");
        } else if (this.mapChoice === "arena") {
            await this.loadGLBMap("fps_shooter_game_arena_map_v3.glb");
        } else if (this.mapChoice === "ghost_city") {
            await this.loadGLBMap("BLD_Ghost_city.glb");
        } else {
            await this.loadGLBMap("village_lowres.glb");
        }
    }

    public async loadGLBMap(filename: string) {
        try {
            const onProgress = (evt: any) => {
                if (evt.lengthComputable) {
                    const percentage = (evt.loaded * 100 / evt.total).toFixed(0);
                    const btnText = document.getElementById("btn-deploy-text");
                    if (btnText) {
                        btnText.innerText = `DOWNLOADING MAP... ${percentage}%`;
                    }
                } else {
                    const btnText = document.getElementById("btn-deploy-text");
                    if (btnText) {
                        const mb = (evt.loaded / (1024 * 1024)).toFixed(1);
                        btnText.innerText = `DOWNLOADING MAP... ${mb}MB`;
                    }
                }
            };
            
            const container = await SceneLoader.LoadAssetContainerAsync("./maps/", filename, this.scene, onProgress);

            // Strip any built-in cameras or lights from the GLB so they don't ruin our scene's carefully tuned lighting & camera setup
            container.cameras.forEach(c => c.dispose());
            container.lights.forEach(l => l.dispose());
            container.cameras = [];
            container.lights = [];
            
            container.addAllToScene();

            // Find a valid object in the map to use as a dynamic spawn point
            let spawnTarget = null;
            for (const m of container.meshes) {
                if (m.getTotalVertices() > 100 && m.name !== "__root__") { // Find a reasonably sized object
                    spawnTarget = m;
                    break; // Just grab the first decent mesh
                }
            }

            if (spawnTarget) {
                spawnTarget.computeWorldMatrix(true);
                const bounds = spawnTarget.getBoundingInfo().boundingBox;
                (window as any).SPAWN_POINT = bounds.centerWorld.add(new Vector3(0, Math.max(5, bounds.maximumWorld.y - bounds.centerWorld.y + 2), 0));
                console.log("Dynamic Spawn Point set to:", (window as any).SPAWN_POINT, "above object:", spawnTarget.name);
            } else {
                (window as any).SPAWN_POINT = new Vector3(0, 10, 0);
            }
            
            console.log(`Successfully loaded map meshes:`, container.meshes.length);

            container.meshes.forEach((mesh) => {
                if (!mesh) return;
                
                // Reduce extreme reflectivity (make ground less mirror-like)
                if (mesh.material && mesh.material.getClassName() === "PBRMaterial") {
                    const pbr = mesh.material as any;
                    if (this.mapChoice === "village") {
                        pbr.metallic = 0.0;
                        pbr.roughness = 0.95; // Rough concrete/dirt
                    } else {
                        // Generally tone down pure mirrors unless they are explicitly marked
                        if (pbr.metallic > 0.8 && pbr.roughness < 0.2) {
                            pbr.roughness = 0.4;
                        }
                    }
                }

                // Add to shadow generator (only non-root, geometry-bearing meshes)
                if (this.shadowGenerator && mesh.name !== "__root__" && mesh.getTotalVertices() > 0) {
                    // Only cast shadows if mesh isn't an explicit ground plane to save GPU draw calls
                    const isGround = mesh.name.toLowerCase().includes("ground") || mesh.name.toLowerCase().includes("floor") || mesh.name.toLowerCase().includes("terrain");
                    if (!isGround) {
                        this.shadowGenerator.addShadowCaster(mesh, true);
                    }
                    mesh.receiveShadows = true;
                }

                // Add physics hitboxes (only for visible geometry, skipping pure transforms/bones)
                // In babylon, geometry is usually on meshes with getTotalVertices() > 0
                const vertexCount = mesh.getTotalVertices();
                if (vertexCount > 0) {
                    // CRITICAL WEBGPU FIX #2: Reduce varying interpolators
                    mesh.useVertexColors = false; 

                    try {
                        new PhysicsAggregate(mesh, PhysicsShapeType.MESH, { mass: 0, friction: 0.0, restitution: 0 }, this.scene);
                    } catch (e) {
                        console.warn(`Failed to create physics for ${mesh.name}:`, e);
                    }
                }
            });

            // If the map comes with animations (moving platforms etc.), play them
            container.animationGroups.forEach(ag => ag.play(true));
            
        } catch (e) {
            console.error(`Failed to load external map: ${filename}`, e);
        }
    }
}
