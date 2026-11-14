import { ArriveBehavior, FleeBehavior, SeekBehavior, SeparationBehavior, Vector3, Vehicle } from 'yuka';
import type { Vec3 } from './world-geometry.js';

export type SteeringOptions = {
  strafe?: number;
  fleeFrom?: Vec3;
  neighbors?: Vec3[];
  separationWeight?: number;
  maxSpeed?: number;
};

/** Yuka selects desired velocity; the authoritative drone solver owns integration and collision. */
export class BotSteering {
  private readonly vehicle = new Vehicle();
  private readonly target = new Vector3();
  private readonly threat = new Vector3();
  private readonly force = new Vector3();
  private readonly separationForce = new Vector3();
  private readonly arrive = new ArriveBehavior(this.target, 0.65, 0.18);
  private readonly seek = new SeekBehavior(this.target);
  private readonly flee = new FleeBehavior(this.threat, 25);
  private readonly separation = new SeparationBehavior();
  private readonly neighborVehicles: Vehicle[] = [];

  command(
    position: Vec3,
    velocity: Vec3,
    goal: Vec3,
    yaw: number,
    finalWaypoint: boolean,
    options?: SteeringOptions
  ): { x: number; y: number; z: number } {
    this.vehicle.position.set(...position);
    this.vehicle.velocity.set(...velocity);
    const speed = options?.maxSpeed ?? 8;
    this.vehicle.maxSpeed = speed;
    this.target.set(...goal);

    if (options?.fleeFrom) {
      this.threat.set(...options.fleeFrom);
      this.flee.calculate(this.vehicle, this.force);
    } else if (finalWaypoint) {
      this.arrive.calculate(this.vehicle, this.force);
    } else {
      this.seek.calculate(this.vehicle, this.force);
    }

    if (options?.neighbors && options.neighbors.length > 0) {
      const count = options.neighbors.length;
      while (this.neighborVehicles.length < count) this.neighborVehicles.push(new Vehicle());
      this.vehicle.neighbors.length = 0;
      for (let i = 0; i < count; i++) {
        this.neighborVehicles[i].position.set(...options.neighbors[i]);
        this.vehicle.neighbors.push(this.neighborVehicles[i]);
      }
      this.separationForce.set(0, 0, 0);
      this.separation.calculate(this.vehicle, this.separationForce);
      const sepWeight = options.separationWeight ?? 1.2;
      this.force.add(this.separationForce.multiplyScalar(sepWeight));
    }

    if (options?.strafe && options.strafe !== 0) {
      const dx = goal[0] - position[0];
      const dz = goal[2] - position[2];
      const len = Math.hypot(dx, dz);
      if (len > 0.1) {
        const strafeMag = options.strafe * speed * 0.45;
        this.force.x += (-dz / len) * strafeMag;
        this.force.z += (dx / len) * strafeMag;
      }
    }

    this.force.add(this.vehicle.velocity);
    const c = Math.cos(yaw), s = Math.sin(yaw);
    const x = (c * this.force.x - s * this.force.z) / speed;
    const z = (-s * this.force.x - c * this.force.z) / speed;
    const y = this.force.y / 6;
    const magnitude = Math.max(1, Math.hypot(x, y, z));
    return { x: x / magnitude, y: y / magnitude, z: z / magnitude };
  }
}


