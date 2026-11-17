import assert from 'node:assert/strict';
import test from 'node:test';
import { BotSimulation, type BotPlayer, insertNearestCandidate } from './bot-simulation.js';
import { createConquestState, stepConquest } from './conquest-simulation.js';
import { INDUSTRIAL_SPAWNS, loadWorldGeometry } from './world-geometry.js';

function human(username: string, spawn: readonly number[], team = 'B'): BotPlayer {
  return { username, x: spawn[0], y: spawn[1] + 0.9, z: spawn[2], health: 100, kills: 0, deaths: 0, team, is_dead: false, weapon_id: 'ak47', ammo: 30, driving_vehicle: '' };
}

test('server bot roster yields capacity to humans and assigns balanced TDM teams', () => {
  const sim = new BotSimulation();
  const first = human('human-a', INDUSTRIAL_SPAWNS[0], 'A');
  const roster = sim.sync([first], 1000, 'TDM');
  assert.equal(roster.joined.length, 7);
  assert.equal(roster.joined.every((bot) => bot.is_bot), true);
  assert.equal(roster.joined.every((bot) => bot.username.startsWith('[BOT] ')), true);
  assert.ok(Math.abs(roster.joined[0].y - (INDUSTRIAL_SPAWNS[0][1] + 0.9)) < 1e-6, 'bot state stores its center above its authored ground spawn');
  const teamA = roster.joined.filter((bot) => bot.team === 'A').length;
  const teamB = roster.joined.filter((bot) => bot.team === 'B').length;
  assert.ok(Math.abs((teamA + 1) - teamB) <= 1);

  const lessBots = sim.sync([first, human('human-b', INDUSTRIAL_SPAWNS[10], 'B')], 1100, 'TDM');
  assert.equal(lessBots.joined.length, 0);
  assert.equal(lessBots.removed.length, 1);
  assert.equal(sim.botIds.length, 6);
  const empty = sim.sync([], 1200, 'TDM');
  assert.equal(empty.removed.length, 6);
  assert.equal(sim.botIds.length, 0);
});

test('bot combat waits for reaction time, uses the real Industrial line of sight, and respawns authoritatively', () => {
  const sim = new BotSimulation();
  const target = human('target', INDUSTRIAL_SPAWNS[10], 'B');
  const humans = Array.from({ length: 7 }, (_, i) => human(`human-${i}`, INDUSTRIAL_SPAWNS[i % INDUSTRIAL_SPAWNS.length], i % 2 ? 'B' : 'A'));
  const created = sim.sync(humans, 1000, 'FFA');
  assert.equal(created.joined.length, 1);
  const bot = created.joined[0];
  bot.x = INDUSTRIAL_SPAWNS[0][0]; bot.y = INDUSTRIAL_SPAWNS[0][1] + 0.9; bot.z = INDUSTRIAL_SPAWNS[0][2];
  bot.yaw = Math.atan2(bot.x - target.x, bot.z - target.z);
  const players = new Map<string, BotPlayer>([[bot.username, bot], [target.username, target]]);
  const shots: unknown[] = [];
  sim.step(players, 1 / 30, 1000, { onShot: (shot) => shots.push(shot) });
  assert.equal(shots.length, 0, 'a newly acquired target cannot be fired on before bot reaction delay');
  sim.step(players, 1 / 30, 2500, { onShot: (shot) => shots.push(shot) });
  assert.ok(shots.length > 0, 'an acquired visible target receives a server-side shot event');

  bot.is_dead = true; bot.health = 0; bot.deaths = 1;
  sim.markDead(bot.username, 3000);
  sim.step(players, 1 / 30, 5999, { onShot: () => {} });
  assert.equal(bot.is_dead, true);
  sim.step(players, 1 / 30, 6000, { onShot: () => {} });
  assert.equal(bot.is_dead, false);
  assert.equal(bot.health, 100);
});

test('bots turn toward observed targets at a bounded rate before firing', () => {
  const sim = new BotSimulation();
  const humans = Array.from({ length: 7 }, (_, i) => human(`turn-human-${i}`, INDUSTRIAL_SPAWNS[i], 'B'));
  const bot = sim.sync(humans, 10_000, 'FFA').joined[0];
  const target = human('turn-target', [-12, 1.3, -12], 'A');
  bot.x = -12; bot.y = 0.9; bot.z = -10;
  const desiredYaw = Math.atan2(bot.x - target.x, bot.z - target.z);
  bot.yaw = desiredYaw + Math.PI;
  const players = new Map<string, BotPlayer>([[bot.username, bot], [target.username, target]]);
  const shots: number[] = [];

  sim.step(players, 0.1, 10_000, { onShot: () => shots.push(10_000) });
  for (let now = 10_100; now <= 10_900; now += 100) {
    sim.step(players, 0.1, now, { onShot: () => shots.push(now) });
  }
  assert.equal(shots.length, 0, 'the bot cannot snap around and fire while its aim is still turning');

  for (let now = 11_000; now <= 13_000 && shots.length === 0; now += 100) {
    sim.step(players, 0.1, now, { onShot: () => shots.push(now) });
  }
  assert.ok(shots.length > 0, 'the bot fires after its bounded turn reaches the target');
});

test('DMR fire cadence uses deliberate single shots with longer pauses', () => {
  const sim = new BotSimulation();
  const humans = Array.from({ length: 7 }, (_, i) => human(`cadence-human-${i}`, INDUSTRIAL_SPAWNS[i], 'B'));
  const bot = sim.sync(humans, 20_000, 'FFA').joined[0];
  bot.x = INDUSTRIAL_SPAWNS[0][0]; bot.y = INDUSTRIAL_SPAWNS[0][1] + 0.9; bot.z = INDUSTRIAL_SPAWNS[0][2];
  bot.weapon_id = 'dmr';
  const target = human('cadence-target', INDUSTRIAL_SPAWNS[1], 'A');
  bot.yaw = Math.atan2(bot.x - target.x, bot.z - target.z);
  const players = new Map<string, BotPlayer>([[bot.username, bot], [target.username, target]]);
  const shotTimes: number[] = [];
  for (let now = 20_000; now <= 28_000; now += 100) {
    sim.step(players, 0.1, now, { onShot: () => shotTimes.push(now) });
  }
  assert.ok(shotTimes.length >= 2, 'the visible target receives repeated DMR shots');
  assert.ok(shotTimes.slice(1).every((time, i) => time - shotTimes[i] >= 700), 'DMR shots are separated by the RPM interval and a single-shot pause');
});

test('bots do not acquire or shoot targets through the authored warehouse wall', () => {
  const sim = new BotSimulation();
  const target = human('behind-wall', [-8, 0.9, -10], 'A');
  const humans = Array.from({ length: 7 }, (_, i) => human(`h-${i}`, INDUSTRIAL_SPAWNS[i], 'B'));
  const { joined } = sim.sync(humans, 5000, 'FFA');
  const bot = joined[0];
  bot.x = -12; bot.y = 0.9; bot.z = -10; bot.yaw = -Math.PI / 2;
  target.x = -8; target.y = 0.9; target.z = -10;
  const players = new Map<string, BotPlayer>([[bot.username, bot], [target.username, target]]);
  const shots: unknown[] = [];
  for (let now = 5000; now < 8000; now += 100) sim.step(players, 0.1, now, { onShot: (shot) => shots.push(shot) });
  assert.equal(shots.length, 0);
});

test('Conquest objective goals replace idle patrol goals when no enemy is visible', () => {
  const sim = new BotSimulation();
  const humans = Array.from({ length: 7 }, (_, i) => {
    const actor = human(`idle-human-${i}`, INDUSTRIAL_SPAWNS[i], i % 2 ? 'B' : 'A');
    actor.is_dead = true;
    return actor;
  });
  const bot = sim.sync(humans, 10_000, 'TDM').joined[0];
  const players = new Map<string, BotPlayer>([[bot.username, bot], ...humans.map((actor) => [actor.username, actor] as [string, BotPlayer])]);
  let goals = 0;
  const goal = INDUSTRIAL_SPAWNS[10];
  sim.step(players, 1 / 30, 10_000, { onShot: () => {}, objectiveGoal: (current) => { assert.equal(current.username, bot.username); goals++; return goal; } });
  assert.equal(goals, 1, 'idle bots ask the mode for their objective destination');
  assert.ok(bot.x !== goal[0] || bot.z !== goal[2], 'the bot begins navigating toward its objective');
});

test('bots anchor to conquest objectives and capture points while defending against threats', () => {
  const geometry = loadWorldGeometry('industrial')!;
  const sim = new BotSimulation(geometry);
  const conquest = createConquestState(geometry.spawns);
  const targetObj = conquest.objectives[0];
  const humanPilot = human('pilot-1', geometry.spawns[2], 'A');
  const { joined } = sim.sync([humanPilot], 1000, 'TDM');
  const botA = joined.find((b) => b.team === 'A')!;
  const botB = joined.find((b) => b.team === 'B')!;

  // Place botA inside objective 0
  botA.x = targetObj.x;
  botA.y = targetObj.y + 0.9;
  botA.z = targetObj.z;

  // Place enemy botB 28m away
  botB.x = targetObj.x + 28;
  botB.y = targetObj.y + 0.9;
  botB.z = targetObj.z;

  const players = new Map([humanPilot, botA, botB].map((actor) => [actor.username, actor]));

  // Step simulation for 6 seconds (180 ticks at 30Hz)
  for (let tick = 0; tick < 180; tick++) {
    const nowMs = 1000 + tick * (1000 / 30);
    sim.step(players, 1 / 30, nowMs, {
      onShot: () => {},
      objectiveGoal: () => ({ position: [targetObj.x, targetObj.y + 0.9, targetObj.z], radius: targetObj.radius })
    });
    stepConquest(conquest, players.values(), 1 / 30);
  }

  // BotA must have remained within objective radius the entire time
  const dBotA = Math.hypot(botA.x - targetObj.x, botA.z - targetObj.z);
  assert.ok(dBotA <= targetObj.radius, `botA remained anchored in capture zone: ${dBotA} <= ${targetObj.radius}`);
  // Point 0 should have accumulated progress or been captured by team A
  assert.ok(targetObj.progress > 0 || targetObj.owner === 'A', 'anchored bot generated capture progress');
});

test('Canyon bots accelerate away from their spawns at the live tick rate', () => {
  const geometry = loadWorldGeometry('canyon')!;
  const sim = new BotSimulation(geometry);
  const pilot = human('canyon-pilot', geometry.spawns[0], 'A');
  const { joined } = sim.sync([pilot], 1000, 'TDM');
  const players = new Map([pilot, ...joined].map((actor) => [actor.username, actor]));
  const starts = joined.map(({ x, z }) => ({ x, z }));
  for (let tick = 0; tick < 360; tick++) {
    sim.step(players, 1 / 60, 1000 + tick * 1000 / 60, { onShot: () => {} });
  }
  const moved = joined.filter((bot, i) => Math.hypot(bot.x - starts[i].x, bot.z - starts[i].z) > 0.5);
  assert.ok(moved.length >= 4, 'most of the bot roster should travel beyond its spawn');
});

test('insertNearestCandidate maintains exact bounded ascending order with stable index tie-breaking', () => {
  const indices = new Int32Array(4);
  const distances = new Float64Array(4);
  let count = 0;

  // Insert items out of order, including identical distances to test stable tie-breaking
  const items = [
    { idx: 10, d: 50 },
    { idx: 5, d: 10 },
    { idx: 8, d: 20 },
    { idx: 3, d: 20 }, // tie with idx 8, but idx 3 < 8, so 3 must come before 8
    { idx: 12, d: 5 },
    { idx: 7, d: 20 }, // tie with 3 and 8: 3 < 7 < 8
  ];

  for (const item of items) {
    count = insertNearestCandidate(indices, distances, count, 4, item.idx, item.d);
  }

  assert.equal(count, 4);
  // Expected top 4:
  // d=5 (idx 12)
  // d=10 (idx 5)
  // d=20 (idx 3)
  // d=20 (idx 7)
  // (idx 8 dropped because capacity is 4)
  assert.equal(indices[0], 12);
  assert.equal(distances[0], 5);
  assert.equal(indices[1], 5);
  assert.equal(distances[1], 10);
  assert.equal(indices[2], 3);
  assert.equal(distances[2], 20);
  assert.equal(indices[3], 7);
  assert.equal(distances[3], 20);
});
