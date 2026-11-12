import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import test from 'node:test';
import { capsuleTriangle } from './capsule-contact.js';
import { stepDroneFlight, type DroneInput } from './drone-flight.js';
import { loadWorldGeometry, PLAYABLE_MAPS, settledVerticalVelocity, type Vec3, WorldGeometry } from './world-geometry.js';

type Triangle = readonly [number, number, number, number, number, number, number, number, number];

function triangle(a: Vec3, b: Vec3, c: Vec3): Triangle {
  return [a[0], a[1], a[2], b[0], b[1], b[2], c[0], c[1], c[2]];
}

function horizontalQuad(y: number, minX: number, maxX: number, minZ: number, maxZ: number): Triangle[] {
  const a: Vec3 = [minX, y, minZ], b: Vec3 = [maxX, y, maxZ], c: Vec3 = [maxX, y, minZ], d: Vec3 = [minX, y, maxZ];
  return [triangle(a, b, c), triangle(a, d, b)];
}

function downwardQuad(y: number, minX: number, maxX: number, minZ: number, maxZ: number): Triangle[] {
  return horizontalQuad(y, minX, maxX, minZ, maxZ).map(([ax, ay, az, bx, by, bz, cx, cy, cz]) => [ax, ay, az, cx, cy, cz, bx, by, bz]);
}

function verticalQuadX(x: number, minY: number, maxY: number, minZ: number, maxZ: number): Triangle[] {
  const a: Vec3 = [x, minY, minZ], b: Vec3 = [x, maxY, minZ], c: Vec3 = [x, maxY, maxZ], d: Vec3 = [x, minY, maxZ];
  return [triangle(a, b, c), triangle(a, c, d)];
}

function rampQuad(minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number): Triangle[] {
  const a: Vec3 = [minX, minY, minZ], b: Vec3 = [maxX, maxY, maxZ], c: Vec3 = [maxX, maxY, minZ], d: Vec3 = [minX, minY, maxZ];
  return [triangle(a, b, c), triangle(a, d, b)];
}

function world(triangles: Triangle[], spawn: Vec3 = [0, 0, 0]): WorldGeometry {
  const flat = triangles.flatMap((item) => [...item]);
  const xs: number[] = [], ys: number[] = [], zs: number[] = [];
  for (let index = 0; index < flat.length; index += 3) { xs.push(flat[index]); ys.push(flat[index + 1]); zs.push(flat[index + 2]); }
  const nodes = [Math.min(...xs), Math.min(...ys), Math.min(...zs), Math.max(...xs), Math.max(...ys), Math.max(...zs), -1, -1, 0, triangles.length];
  return new WorldGeometry('dust2', { name: 'dust2', spawns: [[...spawn]], triangles: flat, nodes, order: triangles.map((_, index) => index) });
}

function flatWorld(minX = -10, maxX = 10, minZ = -10, maxZ = 10): WorldGeometry {
  return world(horizontalQuad(0, minX, maxX, minZ, maxZ));
}

test('capsuleTriangle reports the expected flat-ground skin contact', () => {
  const ground = Float32Array.from(horizontalQuad(0, -2, 2, -2, 2)[0]);
  const contact = capsuleTriangle([0, 0, 0], 0.4, 1.8, ground, 0, 0.008);
  assert.ok(contact, 'capsule should overlap the configured ground skin');
  assert.ok(contact.normal[1] > 0.99, `ground normal should point up: ${contact.normal}`);
  assert.ok(contact.depth > 0.007 && contact.depth < 0.009, `ground skin depth should be 8 mm: ${contact.depth}`);
  assert.equal(capsuleTriangle([0, 0.02, 0], 0.4, 1.8, ground, 0, 0), null, 'capsule above the surface should not overlap without margin');
});

test('capsule remains supported at a thin ledge edge but not in true air', () => {
  const geometry = world(horizontalQuad(0, -4, 1, -4, 4));
  const edge: Vec3 = [1.2, 0, 0];
  assert.equal(geometry.floorHeight(edge[0], edge[2], 3), undefined, 'centre ray should miss beyond the ledge edge');
  assert.equal(geometry.isGrounded(edge), true, 'lower capsule hemisphere should still touch the ledge');
  assert.equal(geometry.isGrounded([1.6, 0, 0]), false, 'capsule should not stay grounded after losing edge support');
  const airborne: Vec3 = [2.0, 0.1, 0];
  assert.equal(geometry.isGrounded(airborne), false);
  assert.equal(settledVerticalVelocity(-4, -0.2, -0.2, geometry.isGrounded(airborne)), -4,
    'true airborne velocity must not be cleared just because no floor ray hit exists');
});

test('capsule follows a ramp and keeps walkable ground contact', () => {
  const geometry = world(rampQuad(-5, 5, 0, 1.5, -4, 4));
  const from: Vec3 = [-2, 0.45, 0], to: Vec3 = [2, 1.05, 0];
  assert.equal(geometry.isGrounded(from), true);
  assert.equal(geometry.isGrounded(to), true);
  const resolved = geometry.resolveMove(from, to);
  assert.ok(resolved[0] > 1.8, `capsule should climb the walkable ramp: ${resolved}`);
  assert.ok(resolved[1] > 0.8, `feet should rise with the ramp: ${resolved}`);
  assert.ok(geometry.isGrounded(resolved), `resolved capsule should retain ramp support: ${resolved}`);
});

test('vertical wall blocks forward motion while preserving tangential slide', () => {
  const geometry = world([...horizontalQuad(0, -5, 5, -5, 5), ...verticalQuadX(0, 0, 3, -5, 5)], [-1, 0, -1]);
  const from: Vec3 = [-1, 0, -1], requested: Vec3 = [1, 0, 2];
  const resolved = geometry.resolveMove(from, requested);
  assert.ok(resolved[0] < -0.39 && resolved[0] > -0.55, `capsule should stop one radius from the wall: ${resolved}`);
  assert.ok(resolved[2] > 1.8, `capsule should continue sliding along the wall: ${resolved}`);
});

test('jumping into a low ceiling resolves upward motion and clears vertical speed', () => {
  const geometry = world([...horizontalQuad(0, -3, 3, -3, 3), ...downwardQuad(1.95, -3, 3, -3, 3)], [0, 0, 0]);
  const requestedY = 0.5;
  const resolved = geometry.resolveMove([0, 0, 0], [0, requestedY, 0]);
  assert.ok(resolved[1] < requestedY - 0.01, `low ceiling should stop the capsule before requested jump height: ${resolved}`);
  assert.equal(settledVerticalVelocity(5, requestedY, resolved[1], false), 0, 'ceiling contact should settle upward velocity');
  assert.equal(geometry.isGrounded([0, resolved[1], 0]), false, 'ceiling contact must not report false floor support');
  const falling = geometry.resolveMove([0, resolved[1], 0], [0, resolved[1] - 0.2, 0]);
  assert.ok(falling[1] < resolved[1] - 0.05, `ceiling-stopped capsule should resume falling: ${falling}`);
});

test('grounded capsule can climb a low step without teleporting or losing support', () => {
  const stepHeight = 0.3;
  const step = verticalQuadX(0, 0, stepHeight, -4, 4);
  const geometry = world([
    ...horizontalQuad(0, -5, 5, -4, 4),
    ...horizontalQuad(stepHeight, 0, 5, -4, 4),
    ...step,
  ], [-1, 0, 0]);
  const from: Vec3 = [-1, 0, 0], requested: Vec3 = [1.5, 0, 0];
  assert.equal(geometry.isGrounded(from), true);
  const resolved = geometry.resolveMove(from, requested);
  assert.ok(resolved[0] > 1.2, `0.3 m step should be traversable: ${resolved}`);
  assert.ok(resolved[1] >= stepHeight - 0.02 && resolved[1] <= stepHeight + 0.1, `feet should settle on the step top: ${resolved}`);
  assert.equal(geometry.isGrounded(resolved), true);
});

test('ground drones cross a low curb but stop at a tall wall', () => {
  for (const mobility_mode of ['wheels', 'tracked']) {
    for (const height of [0.18, 0.65]) {
      const geometry = world([
        ...horizontalQuad(0, -5, 0, -4, 4),
        ...horizontalQuad(height, 0, 15, -4, 4),
        ...verticalQuadX(0, 0, height, -4, 4),
      ], [-1, 0, 0]);
      const input: DroneInput = { move_x: 0, move_y: 0, move_z: 1, yaw: -Math.PI / 2, sprint: 0, mobility_mode };
      let state: { position: Vec3; velocity: Vec3 } = { position: [-1, 0.408, 0], velocity: [0, 0, 0] };
      for (let tick = 0; tick < 120; tick++) state = stepDroneFlight(geometry, state.position, state.velocity, input, 1 / 60);
      if (height < 0.22) {
        assert.ok(state.position[0] > 0.5 && Math.abs(state.position[1] - (height + 0.408)) < 0.02, `${mobility_mode} should settle on curb: ${state.position}`);
      } else {
        assert.ok(state.position[0] < -0.35 && state.position[1] < 0.45, `${mobility_mode} must stop at the wall: ${state.position}`);
      }
      assert.equal(state.velocity[1], 0);
    }
  }
});

test('all playable maps complete bounded walk and jump-landing queries using capsule groundedness', (t) => {
  const startedAt = performance.now();
  let movements = 0;
  for (const mapName of PLAYABLE_MAPS) {
    const geometry = loadWorldGeometry(mapName);
    assert.ok(geometry, `${mapName} should load`);
    const authoredSpawn = geometry.spawns[0];
    const floor = geometry.floorHeight(authoredSpawn[0], authoredSpawn[2], authoredSpawn[1] + 2);
    assert.notEqual(floor, undefined, `${mapName} reference spawn should have a nearby walkable surface`);
    const spawn: Vec3 = [authoredSpawn[0], floor!, authoredSpawn[2]];
    assert.equal(geometry.isGrounded(spawn), true, `${mapName} projected reference position should be capsule-supported`);

    const jumpProbe = geometry.resolveMove(spawn, [spawn[0], spawn[1] + 0.08, spawn[2]]);
    assert.ok(jumpProbe[1] > spawn[1] + 0.01, `${mapName} grounded capsule should be able to start a jump: ${jumpProbe}`);
    const jumpProbeRecovered = geometry.resolveMove(jumpProbe, jumpProbe);
    assert.ok(Math.hypot(jumpProbeRecovered[0] - jumpProbe[0], jumpProbeRecovered[1] - jumpProbe[1], jumpProbeRecovered[2] - jumpProbe[2]) <= 0.03,
      `${mapName} jump probe retained collision penetration: ${jumpProbe} -> ${jumpProbeRecovered}`);

    const walked = geometry.resolveMove(spawn, [spawn[0] + 0.75, spawn[1], spawn[2] + 0.25]);
    assert.ok(walked.every(Number.isFinite), `${mapName} walk produced non-finite position`);
    assert.ok(Math.abs(walked[0] - spawn[0]) <= 0.85 && Math.abs(walked[2] - spawn[2]) <= 0.35,
      `${mapName} walk exceeded its bounded request: ${walked}`);
    movements++;

    let position: Vec3 = spawn;
    let verticalVelocity = 5.0;
    let landed = false;
    let stationaryAirFrames = 0;
    for (let frame = 0; frame < 120; frame++) {
      verticalVelocity -= 9.8 / 60;
      const requestedY = position[1] + verticalVelocity / 60;
      const resolved = geometry.resolveMove(position, [position[0], requestedY, position[2]]);
      const nextVelocity = settledVerticalVelocity(verticalVelocity, requestedY, resolved[1], geometry.isGrounded(resolved));
      if (nextVelocity === 0) {
        const grounded: boolean = geometry.isGrounded(resolved);
        if (verticalVelocity < 0) {
          assert.equal(grounded, true, `${mapName} downward velocity cleared without actual capsule support at frame ${frame}: ${resolved}`);
          landed = true;
        } else {
          assert.equal(grounded, false, `${mapName} upward ceiling contact must not masquerade as grounded at frame ${frame}: ${resolved}`);
        }
        position = resolved;
        verticalVelocity = nextVelocity;
        stationaryAirFrames = grounded ? 0 : stationaryAirFrames + 1;
        assert.ok(stationaryAirFrames <= 2, `${mapName} accumulated stationary airborne frames at ${resolved}`);
        if (landed) break;
        continue;
      }
      assert.notEqual(nextVelocity, 0, `${mapName} unexpected vertical settlement`);
      assert.ok(Math.abs(resolved[1] - spawn[1]) < 8, `${mapName} jump escaped its bounded vertical region: ${resolved}`);
      stationaryAirFrames = geometry.isGrounded(resolved) ? 0 : Math.hypot(resolved[0] - position[0], resolved[1] - position[1], resolved[2] - position[2]) < 0.0001
        ? stationaryAirFrames + 1
        : 0;
      assert.ok(stationaryAirFrames <= 2, `${mapName} accumulated stationary airborne frames at ${resolved}`);
      position = resolved;
      verticalVelocity = nextVelocity;
      movements++;
    }
    assert.equal(landed, true, `${mapName} jump did not settle within the bounded 120-frame simulation`);
    assert.equal(geometry.isGrounded(position), true, `${mapName} landing should be capsule-grounded`);
    const recovered = geometry.resolveMove(position, position);
    assert.ok(Math.hypot(recovered[0] - position[0], recovered[1] - position[1], recovered[2] - position[2]) <= 0.03,
      `${mapName} landing retained collision penetration: ${position} -> ${recovered}`);
  }
  const elapsedMs = performance.now() - startedAt;
  t.diagnostic(`bounded all-map capsule walk/jump: ${PLAYABLE_MAPS.length} maps, ${movements} movement queries, ${elapsedMs.toFixed(1)} ms`);
});

test('blocked horizontal input cannot leave falling players suspended at map corners',()=>{
 for(const map of PLAYABLE_MAPS) {
  const g=loadWorldGeometry(map)!;
  for(let index=0;index<g.spawns.length;index++) {
   let p:Vec3=g.spawns[index],vy=0,blockedAir=0;
   for(let tick=0;tick<360;tick++) {
    const from=p;
    if(tick%90===30&&Math.abs(vy)<.001&&g.isGrounded(p))vy=6.2;
    vy-=18/60;
    const phase=Math.floor(tick/90)%4;
    const target:Vec3=[p[0]+[1,0,-1,0][phase]*6.2/60,p[1]+vy/60,p[2]+[0,1,0,-1][phase]*6.2/60];
    p=g.resolveMove(from,target);
    if(vy<0&&g.isGrounded(p))vy=0;
    else if(vy>0&&p[1]<target[1]-.001)vy=0;
    blockedAir=vy<-.1&&!g.isGrounded(p)&&Math.hypot(p[0]-from[0],p[1]-from[1],p[2]-from[2])<.0001?blockedAir+1:0;
    assert.ok(blockedAir<4,`${map} spawn${index} tick${tick}: suspended without support at ${p}`);
    if(p[1]<-20)break;
   }
  }
 }
});


test('step assist rejects sideways recovery that makes no forward progress',()=>{
 const geometry=loadWorldGeometry('dust2')!;
 const from:Vec3=[-40.408,4.808,5.208];
 const resolved=geometry.resolveMove(from,[from[0],from[1]-.005,from[2]-6.2/60]);
 assert.ok(resolved[1]<=from[1]+.001,`blocked corner must not boost height: ${resolved}`);
});
