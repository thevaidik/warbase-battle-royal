import assert from 'node:assert/strict';
import test from 'node:test';
import { BotSimulation, type BotPlayer } from './bot-simulation.js';
import { INDUSTRIAL_SPAWNS } from './world-geometry.js';

function human(username: string, spawn: readonly number[], team = 'B'): BotPlayer {
  return { username, x: spawn[0], y: spawn[1], z: spawn[2], health: 100, kills: 0, deaths: 0, team, is_dead: false, weapon_id: 'ak47', ammo: 30, driving_vehicle: '' };
}

test('server bot roster yields capacity to humans and assigns balanced TDM teams', () => {
  const sim = new BotSimulation();
  const first = human('human-a', INDUSTRIAL_SPAWNS[0], 'A');
  const roster = sim.sync([first], 1000, 'TDM');
  assert.equal(roster.joined.length, 7);
  assert.equal(roster.joined.every((bot) => bot.is_bot), true);
  assert.equal(roster.joined.every((bot) => bot.username.startsWith('[BOT] ')), true);
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
  bot.x = INDUSTRIAL_SPAWNS[0][0]; bot.y = INDUSTRIAL_SPAWNS[0][1]; bot.z = INDUSTRIAL_SPAWNS[0][2];
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
