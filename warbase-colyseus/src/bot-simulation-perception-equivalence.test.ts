import assert from 'node:assert/strict';
import test from 'node:test';
import { BotSimulation, type BotPlayer } from './bot-simulation.js';
import type { WorldGeometry } from './world-geometry.js';

const geometry = {
  name: 'perception-equivalence-test', navStep: 1, spawns: [[0, 0, 0] as const],
  trace: () => null, rayBlocked: () => false, resolveMove: (_from: readonly number[], to: readonly number[]) => to,
} as unknown as WorldGeometry;

function player(username: string, x: number, y: number, z: number, team: string): BotPlayer {
  return { username, x, y, z, health: 100, kills: 0, deaths: 0, team, is_dead: false, weapon_id: 'ak47', ammo: 30 };
}

type Candidate = Pick<BotPlayer, 'username' | 'x' | 'y' | 'z' | 'team'>;

function expectedFromPreviousPerception(bot: BotPlayer, candidates: Candidate[], incumbent: string): string {
  let best = Infinity;
  let selected = '';
  let currentTarget = incumbent;
  const forward: [number, number, number] = [-Math.sin(bot.yaw ?? 0), 0, -Math.cos(bot.yaw ?? 0)];
  for (const target of candidates) {
    if (target.team === bot.team || target.username === bot.username) continue;
    const dx = target.x - bot.x, dy = target.y - bot.y, dz = target.z - bot.z;
    const distance = Math.hypot(dx, dy, dz);
    if (distance > 70) continue;
    const inView = distance < 10 || dx * forward[0] + dy * forward[1] + dz * forward[2] > distance * 0.05;
    if (!inView) continue;
    const score = distance * (target.username === currentTarget ? 0.8 : 1);
    if (score < best) { best = score; selected = target.username; currentTarget = target.username; }
  }
  return selected;
}

test('squared perception comparisons preserve acquisition, range, incumbent preference, and first-in-order ties', () => {
  const scenarios: Array<{ incumbent?: string; targets: Candidate[] }> = [
    { targets: [player('at-range-edge', 0, 0, -70, 'B'), player('outside-range', 0, 0, -70.0001, 'B')] },
    { targets: [player('inside-ten', 0, 0, -9.9999, 'B'), player('at-ten', 0, 0, -10, 'B')] },
    { targets: [player('first-tie', -3, 0, -4, 'B'), player('second-tie', 3, 0, -4, 'B')] },
    { incumbent: 'incumbent', targets: [player('closer-new', 0, 0, -8, 'B'), player('incumbent', 0, 0, -9, 'B')] },
    { targets: [player('forward-edge', 0, 0, -20, 'B'), player('behind', 0, 0, 20, 'B')] },
  ];

  for (const [index, scenario] of scenarios.entries()) {
    const sim = new BotSimulation(geometry);
    const bot = sim.sync([player(`anchor-${index}`, 100, 0, 0, 'A')], 1000, 'FFA').joined[0];
    bot.team = 'A'; bot.yaw = 0;
    const incumbent = scenario.incumbent ?? '';
    const runtime = sim as unknown as {
      brains: Map<string, { target: string; visible: boolean; lastKnown: [number, number, number] }>;
      perceive: (bot: BotPlayer, brain: { target: string; visible: boolean; lastKnown: [number, number, number] }, players: ReadonlyMap<string, BotPlayer>, nowMs: number) => void;
    };
    const brain = runtime.brains.get(bot.username)!;
    brain.target = incumbent;
    const candidates = scenario.targets.map((target) => ({ ...target, kills: 0, deaths: 0, is_dead: false, weapon_id: 'ak47', ammo: 30 } as BotPlayer));
    const players = new Map<string, BotPlayer>([[bot.username, bot], ...candidates.map((target) => [target.username, target] as [string, BotPlayer])]);

    runtime.perceive(bot, brain, players, 1000);

    assert.equal(brain.target, expectedFromPreviousPerception(bot, scenario.targets, incumbent), `scenario ${index}`);
    assert.equal(brain.visible, brain.target !== '', `scenario ${index}`);
    if (brain.visible) {
      const expected = scenario.targets.find((target) => target.username === brain.target)!;
      assert.deepEqual(brain.lastKnown, [expected.x, expected.y, expected.z], `scenario ${index}`);
    }
  }
});
