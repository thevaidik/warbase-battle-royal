import { readFileSync } from 'node:fs';
import type { Vec3 } from './world-geometry.js';

type DVec = { x: number; y: number; z: number };
type PoseFrame = Array<[number, number, number]>;
type PoseClip = { length: number; loop: boolean; frames: PoseFrame[] };
type PoseData = { fps: number; bones: string[]; clips: Record<string, PoseClip> };
export type HitZone = 'head' | 'torso' | 'stomach' | 'arm' | 'leg';
export type AnimatedHit = { zone: HitZone; fraction: number };
export const REWIND_ANIMATION_CLIPS = ['idle', 'run', 'firing', 'firing walk', 'jump'] as const;
export function animationCodeForClip(animation: string): number {
  const index = REWIND_ANIMATION_CLIPS.indexOf(animation as (typeof REWIND_ANIMATION_CLIPS)[number]);
  return index < 0 ? 0 : index;
}
export function clipForAnimationCode(code: number): (typeof REWIND_ANIMATION_CLIPS)[number] {
  return REWIND_ANIMATION_CLIPS[Math.trunc(code)] ?? 'idle';
}

type CapsuleDef = { from: string; to: string; zone: HitZone; radius: number; trim?: number };
const TOLERANCE = 0.02;
const CAPSULES: CapsuleDef[] = [
  { from: 'mixamorig_Head', to: 'mixamorig_HeadTop_End', zone: 'head', radius: 0.10, trim: 0.25 },
  { from: 'mixamorig_Neck', to: 'mixamorig_Head', zone: 'torso', radius: 0.08 },
  { from: 'mixamorig_Spine1', to: 'mixamorig_Neck', zone: 'torso', radius: 0.18 },
  { from: 'mixamorig_Hips', to: 'mixamorig_Spine1', zone: 'stomach', radius: 0.17 },
  { from: 'mixamorig_LeftArm', to: 'mixamorig_LeftForeArm', zone: 'arm', radius: 0.085 },
  { from: 'mixamorig_LeftForeArm', to: 'mixamorig_LeftHand', zone: 'arm', radius: 0.07 },
  { from: 'mixamorig_RightArm', to: 'mixamorig_RightForeArm', zone: 'arm', radius: 0.085 },
  { from: 'mixamorig_RightForeArm', to: 'mixamorig_RightHand', zone: 'arm', radius: 0.07 },
  { from: 'mixamorig_LeftUpLeg', to: 'mixamorig_LeftLeg', zone: 'leg', radius: 0.10 },
  { from: 'mixamorig_LeftLeg', to: 'mixamorig_LeftFoot', zone: 'leg', radius: 0.09 },
  { from: 'mixamorig_LeftFoot', to: 'mixamorig_LeftToeBase', zone: 'leg', radius: 0.09 },
  { from: 'mixamorig_RightUpLeg', to: 'mixamorig_RightLeg', zone: 'leg', radius: 0.10 },
  { from: 'mixamorig_RightLeg', to: 'mixamorig_RightFoot', zone: 'leg', radius: 0.09 },
  { from: 'mixamorig_RightFoot', to: 'mixamorig_RightToeBase', zone: 'leg', radius: 0.09 },
];
const PRIORITY: Record<HitZone, number> = { head: 4, torso: 3, stomach: 2, arm: 1, leg: 1 };
const poseData = loadPoseData();
const boneIndices = new Map(poseData.bones.map((bone, index) => [bone, index]));

function loadPoseData(): PoseData {
  const path = new URL('./data/soldier_hit_poses.json', import.meta.url);
  const data = JSON.parse(readFileSync(path, 'utf8')) as PoseData;
  if (!(data.fps > 0) || data.bones.length !== 20 || Object.keys(data.clips).length === 0) throw new Error('invalid baked soldier hit pose data');
  const unique = new Set(data.bones);
  if (unique.size !== data.bones.length || data.bones.some((bone) => !bone)) throw new Error('invalid baked soldier hit pose bones');
  for (const capsule of CAPSULES) if (!unique.has(capsule.from) || !unique.has(capsule.to)) throw new Error('invalid baked soldier hit capsule definition');
  for (const clip of Object.values(data.clips)) {
    if (!(clip.length > 0) || clip.frames.length < 2) throw new Error('invalid baked soldier hit clip');
    for (const frame of clip.frames) {
      if (frame.length !== data.bones.length || frame.some((point) => point.length !== 3 || !point.every(Number.isFinite))) throw new Error('invalid baked soldier hit frame');
    }
  }
  return data;
}

const finiteVec = (v: Vec3): boolean => v.length === 3 && v.every(Number.isFinite);
const sub = (a: DVec, b: DVec): DVec => ({ x: a.x - b.x, y: a.y - b.y, z: a.z - b.z });
const add = (a: DVec, b: DVec): DVec => ({ x: a.x + b.x, y: a.y + b.y, z: a.z + b.z });
const scale = (a: DVec, f: number): DVec => ({ x: a.x * f, y: a.y * f, z: a.z * f });
const dot = (a: DVec, b: DVec): number => a.x * b.x + a.y * b.y + a.z * b.z;
const cross = (a: DVec, b: DVec): DVec => ({ x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x });
const length2 = (v: DVec): number => dot(v, v);
const normalized = (v: DVec): DVec | undefined => {
  const length = Math.sqrt(length2(v));
  return length < 1e-9 || !Number.isFinite(length) ? undefined : scale(v, 1 / length);
};
const toD = (v: Vec3): DVec => ({ x: v[0], y: v[1], z: v[2] });
const fromFrame = (v: [number, number, number]): DVec => ({ x: v[0], y: v[1], z: v[2] });

function rotateByQuaternion(v: DVec, x: number, y: number, z: number, w: number): DVec {
  const tx = 2 * (y * v.z - z * v.y), ty = 2 * (z * v.x - x * v.z), tz = 2 * (x * v.y - y * v.x);
  return { x: v.x + w * tx + (y * tz - z * ty), y: v.y + w * ty + (z * tx - x * tz), z: v.z + w * tz + (x * ty - y * tx) };
}

function broadphase(origin: Vec3, end: Vec3, position: Vec3): boolean {
  const lows = [-1.5, -1, -1.5], highs = [1.5, 3, 1.5];
  let enter = 0, leave = 1;
  for (let axis = 0; axis < 3; axis++) {
    const delta = end[axis] - origin[axis], start = origin[axis];
    const low = position[axis] + lows[axis], high = position[axis] + highs[axis];
    if (Math.abs(delta) < 1e-12) { if (start < low || start > high) return false; continue; }
    let a = (low - start) / delta, b = (high - start) / delta;
    if (a > b) [a, b] = [b, a];
    enter = Math.max(enter, a); leave = Math.min(leave, b);
    if (enter > leave) return false;
  }
  return leave >= 0 && enter <= 1;
}

function sampleClip(clip: PoseClip, phase: number): PoseFrame | undefined {
  if (!(clip.length > 0) || clip.frames.length < 2 || !Number.isFinite(phase)) return undefined;
  let normalizedPhase = phase;
  if (clip.loop) { normalizedPhase %= clip.length; if (normalizedPhase < 0) normalizedPhase += clip.length; }
  else normalizedPhase = Math.max(0, Math.min(clip.length, normalizedPhase));
  const framePosition = normalizedPhase / clip.length * (clip.frames.length - 1);
  const first = Math.floor(framePosition);
  if (first >= clip.frames.length - 1) return clip.frames[clip.frames.length - 1];
  const second = first + 1, blend = framePosition - first;
  return clip.frames[first].map((point, bone) => [
    point[0] + (clip.frames[second][bone][0] - point[0]) * blend,
    point[1] + (clip.frames[second][bone][1] - point[1]) * blend,
    point[2] + (clip.frames[second][bone][2] - point[2]) * blend,
  ]);
}

function alignRayToCapsule(rayStart: DVec, rayEnd: DVec, capsuleStart: DVec, capsuleEnd: DVec): { start: DVec; end: DVec; axisLength: number } | undefined {
  const axisVector = sub(capsuleEnd, capsuleStart), axisLength = Math.sqrt(length2(axisVector));
  if (axisLength < 1e-9 || !Number.isFinite(axisLength)) return undefined;
  const axis = scale(axisVector, 1 / axisLength);
  const reference = Math.abs(axis.z) > 0.9 ? { x: 1, y: 0, z: 0 } : { x: 0, y: 0, z: 1 };
  const xAxis = normalized(cross(reference, axis));
  if (!xAxis) return undefined;
  const zAxis = cross(xAxis, axis);
  const center = scale(add(capsuleStart, capsuleEnd), 0.5);
  const align = (point: DVec): DVec => { const r = sub(point, center); return { x: dot(r, xAxis), y: dot(r, axis), z: dot(r, zAxis) }; };
  return { start: align(rayStart), end: align(rayEnd), axisLength };
}

function pointCapsuleDistance2(point: DVec, axisHalf: number): number {
  const y = Math.max(-axisHalf, Math.min(axisHalf, point.y));
  return point.x * point.x + (point.y - y) ** 2 + point.z * point.z;
}

function segmentSphere(start: DVec, delta: DVec, center: DVec, radius: number): number | undefined {
  const relative = sub(start, center), a = length2(delta), b = 2 * dot(relative, delta), c = length2(relative) - radius * radius;
  const discriminant = b * b - 4 * a * c;
  if (discriminant < 0 || a < 1e-12) return undefined;
  let t = (-b - Math.sqrt(discriminant)) / (2 * a);
  if (t < 0) t = (-b + Math.sqrt(discriminant)) / (2 * a);
  return t >= 0 && t <= 1 ? t : undefined;
}

function segmentCapsule(start: DVec, end: DVec, height: number, radius: number): number | undefined {
  const delta = sub(end, start), axisHalf = Math.max(0, height / 2 - radius);
  if (pointCapsuleDistance2(start, axisHalf) <= radius * radius) return 0;
  let best = Number.POSITIVE_INFINITY;
  const a = delta.x * delta.x + delta.z * delta.z;
  const b = 2 * (start.x * delta.x + start.z * delta.z);
  const c = start.x * start.x + start.z * start.z - radius * radius;
  if (a > 1e-12) {
    const disc = b * b - 4 * a * c;
    if (disc >= 0) {
      const root = Math.sqrt(disc);
      for (const t of [(-b - root) / (2 * a), (-b + root) / (2 * a)]) {
        const y = start.y + t * delta.y;
        if (t >= 0 && t <= 1 && Math.abs(y) <= axisHalf && t < best) best = t;
      }
    }
  }
  for (const y of [-axisHalf, axisHalf]) {
    const t = segmentSphere(start, delta, { x: 0, y, z: 0 }, radius);
    if (t !== undefined && t < best) best = t;
  }
  return best <= 1 ? best : undefined;
}

function priority(zone: HitZone): number { return PRIORITY[zone]; }

export function sampleBakedPose(animation: string, phaseSeconds: number): ReadonlyArray<readonly [number, number, number]> | undefined {
  const clip = poseData.clips[animation] ?? poseData.clips.idle;
  return clip ? sampleClip(clip, phaseSeconds) : undefined;
}

export function traceAnimatedHit(origin: Vec3, end: Vec3, position: Vec3, rotation: readonly [number, number, number, number], animation: string, phaseSeconds: number): AnimatedHit | undefined {
  if (![origin, end, position].every(finiteVec) || !rotation.every(Number.isFinite) || !Number.isFinite(phaseSeconds)) return undefined;
  if (!broadphase(origin, end, position)) return undefined;
  const clip = poseData.clips[animation] ?? poseData.clips.idle;
  const pose = clip ? sampleClip(clip, phaseSeconds) : undefined;
  if (!pose) return undefined;
  let [qx, qy, qz, qw] = rotation;
  const qLength = Math.hypot(qx, qy, qz, qw);
  if (qLength < 1e-6) [qx, qy, qz, qw] = [0, 0, 0, 1];
  else [qx, qy, qz, qw] = [qx / qLength, qy / qLength, qz / qLength, qw / qLength];
  const base = toD(position);
  const startWorld = toD(origin), endWorld = toD(end);
  const startLocal = rotateByQuaternion(sub(startWorld, base), -qx, -qy, -qz, qw);
  const endLocal = rotateByQuaternion(sub(endWorld, base), -qx, -qy, -qz, qw);
  if (length2(sub(endLocal, startLocal)) < 1e-12) return undefined;
  let best = Number.POSITIVE_INFINITY, bestPriority = -1;
  let zone: HitZone | undefined;
  for (const capsule of CAPSULES) {
    const fromIndex = boneIndices.get(capsule.from), toIndex = boneIndices.get(capsule.to);
    if (fromIndex === undefined || toIndex === undefined) return undefined;
    let from = fromFrame(pose[fromIndex]), to = fromFrame(pose[toIndex]);
    if (capsule.trim) { const delta = sub(to, from); to = add(to, scale(delta, -capsule.trim)); from = add(from, scale(delta, capsule.trim)); }
    const aligned = alignRayToCapsule(startLocal, endLocal, from, to);
    if (!aligned) continue;
    const fraction = segmentCapsule(aligned.start, aligned.end, aligned.axisLength + 2 * capsule.radius, capsule.radius + TOLERANCE);
    if (fraction === undefined) continue;
    const rank = priority(capsule.zone);
    if (rank > bestPriority || (rank === bestPriority && fraction < best)) { best = fraction; bestPriority = rank; zone = capsule.zone; }
  }
  return zone ? { zone, fraction: best } : undefined;
}
