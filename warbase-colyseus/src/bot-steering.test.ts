import assert from 'node:assert/strict';
import test from 'node:test';
import { BotSteering } from './bot-steering.js';

test('Yuka arrival slows at destinations while transit keeps moving', () => {
  const steering = new BotSteering();
  const arrive = steering.command([0,0,0], [0,0,-4], [0,0,-0.3], 0, true);
  const transit = steering.command([0,0,0], [0,0,-4], [0,0,-0.3], 0, false);
  assert.ok(arrive.z > 0 && arrive.z < 0.1);
  assert.equal(transit.z, 1);
  const stopped = steering.command([0,0,0], [0,0,-4], [0,0,0], 0, true);
  assert.equal(Math.hypot(stopped.x, stopped.y, stopped.z), 0);
});

test('steering remains bounded in 3D and transforms world direction into body input', () => {
  const steering = new BotSteering();
  const diagonal = steering.command([0,0,0], [0,0,0], [10,20,30], 1.2, false);
  assert.ok(Math.hypot(diagonal.x, diagonal.y, diagonal.z) <= 1.000001);
  const turned = steering.command([0,0,0], [0,0,0], [-10,0,0], Math.PI / 2, false);
  assert.ok(turned.z > 0.999 && Math.abs(turned.x) < 0.000001);
});

test('Yuka steering supports lateral strafe bias and threat fleeing', () => {
  const steering = new BotSteering();
  const forward = steering.command([0,0,0], [0,0,0], [0,0,-10], 0, false);
  const strafeRight = steering.command([0,0,0], [0,0,0], [0,0,-10], 0, false, { strafe: 1 });
  assert.ok(strafeRight.x > forward.x, 'positive strafe pushes right');
  const strafeLeft = steering.command([0,0,0], [0,0,0], [0,0,-10], 0, false, { strafe: -1 });
  assert.ok(strafeLeft.x < forward.x, 'negative strafe pushes left');

  const fleeing = steering.command([0,0,0], [0,0,0], [0,0,0], 0, false, { fleeFrom: [0,0,-10] });
  assert.ok(fleeing.z < 0, 'fleeing pushes backward away from threat in front');

  const withoutNeighbor = steering.command([0,0,0], [0,0,0], [0,0,-10], 0, false);
  const withNeighborOnRight = steering.command([0,0,0], [0,0,0], [0,0,-10], 0, false, { neighbors: [[1.5, 0, 0]] });
  assert.ok(withNeighborOnRight.x < withoutNeighbor.x, 'separation behavior repels vehicle left away from right-hand neighbor');
});

