import type { Vec3, WorldGeometry } from './world-geometry.js';
export const DRONE_RADIUS = 0.4;
export const DRONE_SPAWN_OFFSET = 0.9;
export const DRONE_MAX_ALTITUDE = 120;
const DRONE_GRAVITY = 18;
const GROUND_STEP_HEIGHT = 0.52;
// Ordered to match DroneFlight.gd and sent as a numeric SDK input.
export const DRONE_MOBILITY_MODES = ['quad', 'wheels', 'tracked', 'heli', 'wing'] as const;
export type DroneInput = { move_x: number; move_y: number; move_z: number; yaw: number; sprint: number; mobility_mode?: string };

export type ChassisGroundProfile = {
  groundY: number;
  pitch: number;
  roll: number;
  normal: Vec3;
  grounded: boolean;
};

/**
 * 4-Corner Raycast terrain probing for tanks ('tracked') and wheeled vehicles ('wheels').
 * Probes Front-Left, Front-Right, Rear-Left, Rear-Right contact points.
 * Calculates terrain conformance, slope pitch, and banking roll without an external physics library.
 */
export function sampleChassisGroundRays(
  geometry: WorldGeometry,
  position: Vec3,
  yaw: number,
  halfWidth = 0.38,
  halfLength = 0.52
): ChassisGroundProfile {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  const corners: [number, number][] = [
    [-halfWidth, halfLength],
    [halfWidth, halfLength],
    [-halfWidth, -halfLength],
    [halfWidth, -halfLength],
  ];

  let sumY = 0;
  let hits = 0;
  const sumNormal: [number, number, number] = [0, 0, 0];
  const groundHeights: number[] = [];

  for (const [lx, lz] of corners) {
    const wx = position[0] + (c * lx - s * lz);
    const wz = position[2] + (-s * lx - c * lz);
    const top: Vec3 = [wx, position[1] + 0.6, wz];
    const bottom: Vec3 = [wx, position[1] - 1.2, wz];
    const hit = geometry.trace(top, bottom);
    if (hit && Math.abs(hit.normal[1]) > 0.4) {
      const y = top[1] + (bottom[1] - top[1]) * hit.fraction;
      groundHeights.push(y);
      sumY += y;
      sumNormal[0] += hit.normal[0];
      sumNormal[1] += hit.normal[1];
      sumNormal[2] += hit.normal[2];
      hits++;
    } else {
      groundHeights.push(position[1] - DRONE_RADIUS);
    }
  }

  const grounded = hits >= 2;
  const groundY = hits > 0 ? sumY / hits : position[1] - DRONE_RADIUS;
  const frontAvg = (groundHeights[0] + groundHeights[1]) / 2;
  const rearAvg = (groundHeights[2] + groundHeights[3]) / 2;
  const leftAvg = (groundHeights[0] + groundHeights[2]) / 2;
  const rightAvg = (groundHeights[1] + groundHeights[3]) / 2;

  const pitch = Math.atan2(frontAvg - rearAvg, halfLength * 2);
  const roll = Math.atan2(rightAvg - leftAvg, halfWidth * 2);

  const normalLen = Math.hypot(sumNormal[0], sumNormal[1], sumNormal[2]) || 1;
  const normal: Vec3 = [sumNormal[0] / normalLen, sumNormal[1] / normalLen, sumNormal[2] / normalLen];

  return { groundY, pitch, roll, normal, grounded };
}

/** Stabilized flight: acceleration, active braking, and real swept-volume contact.
 * Prediction and authority share these constants and operation order. */
export function stepDroneFlight(geometry: WorldGeometry, position: Vec3, velocity: Vec3, input: DroneInput, dt: number): { position: Vec3; velocity: Vec3 } {
  if(!position.every(Number.isFinite)) {
    const spawn=geometry.spawns[0];return {position:[spawn[0],spawn[1]+DRONE_SPAWN_OFFSET,spawn[2]],velocity:[0,0,0]};
  }
  const elapsed=Math.max(0,Math.min(0.1,dt));
  if(!Number.isFinite(elapsed) || elapsed===0 || ![...position,...velocity,input.move_x,input.move_y,input.move_z,input.yaw,input.sprint].every(Number.isFinite))return {position,velocity:[0,0,0]};
  const y=Math.max(-1,Math.min(1,input.move_y)),z=Math.max(-1,Math.min(1,input.move_z));
  const mode=['quad','wheels','tracked','heli','wing'].includes(input.mobility_mode ?? '')?input.mobility_mode:'quad';
  const x = (mode === 'tracked' || mode === 'wheels') ? 0 : Math.max(-1, Math.min(1, input.move_x));
  const ground=mode==='tracked'||mode==='wheels',wing=mode==='wing';
  const magnitude=Math.max(1,ground||wing?Math.hypot(x,z):Math.hypot(x,y,z)),speed=ground?(mode==='tracked'?4.5:6):(wing?(input.sprint>0.5?17:11):(input.sprint>0.5?14:8)),vertical=mode==='heli'?(input.sprint>0.5?10:7):(mode==='quad'?(input.sprint>0.5?9:6):0);
  const c=Math.cos(input.yaw),s=Math.sin(input.yaw);
  const horizontalTargetX=(x*c-z*s)/magnitude*speed,horizontalTargetZ=(-x*s-z*c)/magnitude*speed;
  const target: Vec3 = [horizontalTargetX, ground ? 0 : y / magnitude * vertical, horizontalTargetZ];
  const response=1-Math.exp(-(x===0&&y===0&&z===0?12:(ground?6:9))*elapsed);
  const next=velocity.map((v,i)=>v+(target[i]-v)*response) as [number,number,number];
  let uphillAssist = 0;
  if (mode === 'tracked' || mode === 'wheels') {
    const currentSpeed = -velocity[0] * s - velocity[2] * c;
    const isSprint = input.sprint > 0.5;
    const desiredSpeed = z * (z < 0 ? (mode === 'wheels' ? 5.5 : 3.8) : (mode === 'wheels' ? (isSprint ? 14.5 : 8.0) : (isSprint ? 8.5 : 4.8)));
    if (Math.abs(desiredSpeed) > 0.01) {
      const probeDist = 0.4;
      const moveSign = desiredSpeed < 0 ? -1 : 1;
      const probeX = position[0] + (-s) * probeDist * moveSign;
      const probeZ = position[2] + (-c) * probeDist * moveSign;
      const aheadFloor = geometry.floorHeight(probeX, probeZ, position[1] + 1.0);
      const hereFloor = geometry.floorHeight(position[0], position[2], position[1] + 0.6) ?? (position[1] - DRONE_RADIUS);
      if (aheadFloor !== undefined && (aheadFloor - hereFloor) > 0.005) {
        const slopeDy = aheadFloor - hereFloor;
        uphillAssist = Math.min(10, Math.abs(desiredSpeed) * (slopeDy / probeDist));
      }
    }
    const braking = z === 0 || currentSpeed * desiredSpeed < 0;
    const traction = braking ? 18 : (uphillAssist > 0 ? 20 : (mode === 'wheels' ? 8.5 : 9.0));
    const difference = desiredSpeed - currentSpeed;
    const speedAlongTrack = currentSpeed + Math.sign(difference) * Math.min(Math.abs(difference), traction * elapsed);
    next[0] = -s * speedAlongTrack;
    next[2] = -c * speedAlongTrack;
  }
  if (wing || mode === 'heli') {
    const forwardSpeed = -velocity[0] * s - velocity[2] * c;
    const sidewaysSpeed = velocity[0] * c - velocity[2] * s;
    if (wing) {
      const throttle = Math.max(0, z);
      const thrust = (input.sprint > 0.5 ? 16 : 10.5) * throttle;
      const drag = (0.065 + 0.045 * Math.abs(y) + (z < 0 ? 0.16 : 0)) * Math.abs(forwardSpeed) * forwardSpeed;
      const liftAuthority = Math.min(1, (Math.max(0, forwardSpeed) / 8) ** 2);
      const climbTarget = y * 9 * liftAuthority;
      // Climbing trades forward energy for height; descending recovers speed.
      const gravityAlongFlight = 9.81 * liftAuthority * Math.max(-0.7, Math.min(0.7, velocity[1] / Math.max(6, Math.hypot(forwardSpeed, velocity[1]))));
      const speed = Math.max(0, forwardSpeed + (thrust - drag - gravityAlongFlight) * elapsed);
      const lateral = sidewaysSpeed * Math.exp(-1.8 * elapsed);
      next[0] = -s * speed + c * lateral;
      next[2] = -c * speed - s * lateral;
      const climbResponse = 1 - Math.exp(-4 * elapsed);
      const climb = velocity[1] + (climbTarget - velocity[1]) * climbResponse;
      next[1] = Math.max(-15, Math.min(9, climb - DRONE_GRAVITY * (1 - liftAuthority) * elapsed));
    } else {
      const forwardTilt = Math.max(0, z);
      const tiltScale = Math.max(1, Math.hypot(x, forwardTilt));
      const thrust = input.sprint > 0.5 ? 16 : 12;
      const horizontalDrag = x === 0 && forwardTilt === 0 ? 2.8 : 1.4;
      const retention = Math.exp(-horizontalDrag * elapsed);
      next[0] = velocity[0] * retention + (c * x - s * forwardTilt) / tiltScale * thrust * elapsed;
      next[2] = velocity[2] * retention + (-s * x - c * forwardTilt) / tiltScale * thrust * elapsed;
      const climbTarget = z < 0 && Math.abs(y) < 0.00001 ? z * 2.5 : y * vertical;
      const climbDifference = climbTarget - velocity[1];
      next[1] = velocity[1] + Math.sign(climbDifference) * Math.min(Math.abs(climbDifference), 15 * elapsed);
    }
  }
  if (ground) {
    next[1] = uphillAssist > 0 ? uphillAssist : velocity[1] - DRONE_GRAVITY * elapsed;
  }
  const requested:[number,number,number]=[position[0]+next[0]*elapsed,Math.min(DRONE_MAX_ALTITUDE,position[1]+next[1]*elapsed),position[2]+next[2]*elapsed];
  const groundStep = mode === 'wheels' ? 0.58 : GROUND_STEP_HEIGHT;
  const resolved = geometry.resolveFlightMove(position, requested, DRONE_RADIUS, ground ? groundStep : 0);
  const actual:Vec3=[(resolved[0]-position[0])/elapsed,(resolved[1]-position[1])/elapsed,(resolved[2]-position[2])/elapsed];
  const corrected=actual.map((v,i)=>Math.abs(resolved[i]-requested[i])<=0.0006?next[i]:v) as [number,number,number];
  if (ground) corrected[1] = Math.min(0, corrected[1]);
  return {position:resolved,velocity:corrected.map((v,i)=>Math.abs(v)<0.025 || (i===1 && next[1]>0 && requested[1]===DRONE_MAX_ALTITUDE)?0:v) as unknown as Vec3};
}
