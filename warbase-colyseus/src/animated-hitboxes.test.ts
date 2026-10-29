import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { animationCodeForClip, clipForAnimationCode, REWIND_ANIMATION_CLIPS, sampleBakedPose, traceAnimatedHit } from './animated-hitboxes.js';
import type { Vec3 } from './world-geometry.js';

type Frame = ReadonlyArray<readonly [number, number, number]>;
const data = JSON.parse(readFileSync(new URL('./data/soldier_hit_poses.json', import.meta.url), 'utf8')) as { bones: string[] };
const bone = (pose: Frame, name: string): Vec3 => pose[data.bones.indexOf(name)] as Vec3;
const add = (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const sub = (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const mul = (a: Vec3, n: number): Vec3 => [a[0] * n, a[1] * n, a[2] * n];
const cross = (a: Vec3, b: Vec3): Vec3 => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = (a: Vec3): Vec3 => mul(a, 1 / Math.hypot(...a));
const midpoint = (a: Vec3, b: Vec3): Vec3 => mul(add(a, b), 0.5);
function world(local: Vec3, position: Vec3, q: readonly [number, number, number, number]): Vec3 {
  const [x, y, z, w] = q, [lx, ly, lz] = local;
  const tx = 2 * (y * lz - z * ly), ty = 2 * (z * lx - x * lz), tz = 2 * (x * ly - y * lx);
  return [position[0] + lx + w * tx + (y * tz - z * ty), position[1] + ly + w * ty + (z * tx - x * tz), position[2] + lz + w * tz + (x * ty - y * tx)];
}

test('server pose asset is byte-identical to the legacy server source', () => {
  const legacy = readFileSync(new URL('../../warbase-godot/server/internal/engine/soldier_hit_poses.json', import.meta.url));
  const current = readFileSync(new URL('./data/soldier_hit_poses.json', import.meta.url));
  assert.deepEqual(current, legacy);
});

test('tracks the animated head across idle, run, jump, translation and rotation', () => {
  const target: Vec3 = [7, 2, -4], rotation: [number, number, number, number] = [0, Math.sin(Math.PI / 8), 0, Math.cos(Math.PI / 8)];
  for (const [animation, phase] of [['idle', 0], ['idle', 4.3], ['run', 0], ['run', 0.35], ['jump', 0.17], ['jump', 0.6]] as const) {
    const pose = sampleBakedPose(animation, phase)!;
    let from = bone(pose, 'mixamorig_Head'), to = bone(pose, 'mixamorig_HeadTop_End');
    const axis = sub(to, from); from = add(from, mul(axis, 0.25)); to = add(to, mul(axis, -0.25));
    const point = add(from, mul(sub(to, from), 0.82));
    const direction = norm(cross(sub(to, from), [0, 0, 1]));
    const start = world(add(point, mul(direction, 2)), target, rotation), end = world(sub(point, mul(direction, 2)), target, rotation);
    assert.equal(traceAnimatedHit(start, end, target, rotation, animation, phase)?.zone, 'head', `${animation} at ${phase}s`);
  }
});

test('keeps limb-only and penetration zones distinct on the same animated actor', () => {
  assert.equal(traceAnimatedHit([1, 1.25, 0.02], [0.3, 1.25, 0.02], [0, 0, 0], [0, 0, 0, 1], 'idle', 0)?.zone, 'arm');
  assert.equal(traceAnimatedHit([1, 1.25, 0.02], [-1, 1.25, 0.02], [0, 0, 0], [0, 0, 0, 1], 'idle', 0)?.zone, 'torso');
  const phase = 0.21, pose = sampleBakedPose('run', phase)!;
  const a = bone(pose, 'mixamorig_LeftArm'), b = bone(pose, 'mixamorig_LeftForeArm');
  const center = midpoint(a, b), direction = norm(cross(sub(b, a), [0, 1, 0]));
  assert.equal(traceAnimatedHit(add(center, mul(direction, 2)), sub(center, mul(direction, 2)), [0, 0, 0], [0, 0, 0, 1], 'run', phase)?.zone, 'arm');
});

test('uses one discrete clip per rewind snapshot and rejects malformed phases', () => {
  // Each input update changes the clip code atomically; snapshot rewind must not blend enums.
  for (const transition of [['run', 'firing'], ['firing', 'jump'], ['jump', 'run']] as const) {
    const [from, to] = transition;
    const oldCode = animationCodeForClip(from), newCode = animationCodeForClip(to);
    assert.notEqual(oldCode, newCode);
    assert.equal(clipForAnimationCode(oldCode), from);
    assert.equal(clipForAnimationCode(newCode), to);
    assert.ok(sampleBakedPose(clipForAnimationCode(oldCode), 0.12));
    assert.ok(sampleBakedPose(clipForAnimationCode(newCode), 0.12));
  }
  assert.equal(clipForAnimationCode((animationCodeForClip('run') + animationCodeForClip('firing')) / 2), 'run', 'fallback must be deterministic if a non-snapshot value ever appears');
  for (const [code, clip] of REWIND_ANIMATION_CLIPS.entries()) assert.equal(clipForAnimationCode(code), clip);
  const pose = sampleBakedPose('jump', 0.33)!;
  const from = bone(pose, 'mixamorig_Head'), to = bone(pose, 'mixamorig_HeadTop_End');
  const delta = sub(to, from), start = add(from, [1, 0, 2]), end = add(from, [1, 0, -2]);
  assert.ok(delta[1] > 0);
  assert.equal(traceAnimatedHit(start, end, [0, 0, 0], [0, 0, 0, 1], 'jump', Number.NaN), undefined);
  assert.equal(traceAnimatedHit([100, 0, 0], [101, 0, 0], [0, 0, 0], [0, 0, 0, 1], 'run', 0), undefined);
});
