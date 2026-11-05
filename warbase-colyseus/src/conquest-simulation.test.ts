import assert from 'node:assert/strict';
import test from 'node:test';
import { awardConquestKill, CONQUEST_CAPTURE_MS, CONQUEST_TICKET_START, createConquestState, stepConquest, type ConquestPlayer } from './conquest-simulation.js';
import { loadWorldGeometry, PLAYABLE_MAPS } from './world-geometry.js';

const spawns = [[0, 0, 0], [30, 0, 0], [60, 0, 0], [90, 0, 0]];
const player = (team: 'A' | 'B', x = 0, extra: Partial<ConquestPlayer> = {}): ConquestPlayer => ({ team, x, y: 0, z: 0, is_dead: false, ...extra });

test('Conquest creates four distinct objectives from valid map spawns', () => {
  const state = createConquestState(spawns);
  assert.deepEqual(state.objectives.map(({ id }) => id), ['A', 'B', 'C', 'D']);
  assert.equal(state.ticketsA, CONQUEST_TICKET_START);
  assert.throws(() => createConquestState(spawns.slice(0, 3)));
});

test('all playable maps get four separated objectives whose centers do not overlap capture zones', () => {
  for (const map of PLAYABLE_MAPS) {
    const geometry = loadWorldGeometry(map);
    assert.ok(geometry, `${map} geometry exists`);
    const objectives = createConquestState(geometry.spawns).objectives;
    assert.equal(new Set(objectives.map(({ x, y, z }) => `${x},${y},${z}`)).size, 4, `${map} objectives are distinct`);
    for (let i = 0; i < objectives.length; i++) for (let j = i + 1; j < objectives.length; j++) {
      const a = objectives[i], b = objectives[j], distance = Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
      assert.ok(distance > a.radius && distance > b.radius, `${map} objective centers do not fall inside another objective's capture radius`);
      assert.ok(a.radius <= 12 && b.radius <= 12, `${map} capture radii stay within the 12m maximum`);
    }
  }
});

test('uncontested capture advances and contested presence freezes progress', () => {
  const state = createConquestState(spawns);
  const point = state.objectives[0], atPoint = (team: 'A' | 'B') => player(team, point.x, { y: point.y, z: point.z });
  stepConquest(state, [atPoint('A')], 6);
  assert.equal(point.progress, 0.5);
  stepConquest(state, [atPoint('A'), atPoint('B')], 4);
  assert.equal(state.objectives[0].contested, true);
  assert.equal(state.objectives[0].progress, 0.5);
  stepConquest(state, [atPoint('A')], 6);
  assert.equal(state.objectives[0].owner, 'A');
  assert.equal(state.objectives[0].progress, 0);
});

test('enemy ownership must be neutralized before the objective can be captured', () => {
  const state = createConquestState(spawns);
  const point = state.objectives[0], atPoint = player('B', point.x, { y: point.y, z: point.z });
  point.owner = 'A';
  stepConquest(state, [atPoint], CONQUEST_CAPTURE_MS / 1000);
  assert.equal(state.objectives[0].owner, '');
  assert.equal(state.objectives[0].progress, 0);
  stepConquest(state, [atPoint], CONQUEST_CAPTURE_MS / 1000);
  assert.equal(state.objectives[0].owner, 'B');
});

test('dead and vehicle occupants do not contribute to capture', () => {
  const state = createConquestState(spawns);
  const point = state.objectives[0];
  stepConquest(state, [player('A', point.x, { y: point.y, z: point.z, is_dead: true }), player('A', point.x, { y: point.y, z: point.z, driving_vehicle: 'car' })], 5);
  assert.equal(state.objectives[0].progress, 0);
});

test('objective advantage bleeds tickets and kills cost one ticket', () => {
  const state = createConquestState(spawns);
  state.objectives[0].owner = 'A'; state.objectives[1].owner = 'A'; state.objectives[2].owner = 'B';
  stepConquest(state, [], 5);
  assert.equal(state.ticketsB, 499);
  awardConquestKill(state, 'A');
  assert.equal(state.ticketsB, 498);
});

test('zero tickets finishes the match and finished state is immutable', () => {
  const state = createConquestState(spawns);
  state.ticketsB = 1;
  awardConquestKill(state, 'A');
  assert.equal(state.roomState, 'finished'); assert.equal(state.winner, 'A');
  const before = structuredClone(state);
  stepConquest(state, [player('B')], 30);
  awardConquestKill(state, 'B');
  assert.deepEqual(state, before);
});
