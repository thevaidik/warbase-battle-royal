import type { Vec3 } from './world-geometry.js';

export type DroneHit = { zone: 'torso'; fraction: number };

/** Trace a ray segment against the rigid, orientation independent drone body. */
export function traceDroneHit(origin: Vec3, end: Vec3, center: Vec3, radius = 0.45): DroneHit | null {
  if (![...origin, ...end, ...center, radius].every(Number.isFinite) || radius <= 0) return null;
  const d: Vec3 = [end[0] - origin[0], end[1] - origin[1], end[2] - origin[2]];
  const m: Vec3 = [origin[0] - center[0], origin[1] - center[1], origin[2] - center[2]];
  const a = d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
  if (a < 1e-12) return null;
  const b = 2 * (m[0] * d[0] + m[1] * d[1] + m[2] * d[2]);
  const c = m[0] * m[0] + m[1] * m[1] + m[2] * m[2] - radius * radius;
  const discriminant = b * b - 4 * a * c;
  if (discriminant < 0) return null;
  const root = Math.sqrt(discriminant);
  const near = (-b - root) / (2 * a), far = (-b + root) / (2 * a);
  const fraction = near >= 0 ? near : far >= 0 ? 0 : -1;
  return fraction >= 0 && fraction <= 1 ? { zone: 'torso', fraction } : null;
}
