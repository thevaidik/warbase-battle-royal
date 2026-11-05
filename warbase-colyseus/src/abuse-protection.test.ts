import assert from 'node:assert/strict';
import test from 'node:test';
import { canonicalizeUsername, FixedWindowLimiter } from './abuse-protection.js';
import { consumeRoomCreationAllowance } from './battle-room.js';

test('anonymous username admission canonicalizes and bounds display names', () => {
  assert.equal(canonicalizeUsername('  Alice_7  '), 'Alice_7');
  assert.equal(canonicalizeUsername('Ａlice'), 'Alice');
  assert.equal(canonicalizeUsername(''), undefined);
  assert.equal(canonicalizeUsername('[BOT] name'), undefined);
  assert.equal(canonicalizeUsername('name\nadmin'), undefined);
  assert.equal(canonicalizeUsername('<admin>'), undefined);
  assert.equal(canonicalizeUsername('x'.repeat(25)), undefined);
  assert.equal(canonicalizeUsername('x'.repeat(129)), undefined);
});

test('fixed window limiter resets, isolates keys, and bounds key storage', () => {
  const limiter = new FixedWindowLimiter(2);
  assert.equal(limiter.allow('a', 2, 1000, 10), true);
  assert.equal(limiter.allow('a', 2, 1000, 11), true);
  assert.equal(limiter.allow('a', 2, 1000, 12), false);
  assert.equal(limiter.allow('b', 1, 1000, 12), true);
  assert.equal(limiter.allow('a', 1, 1000, 1010), true);
  assert.equal(limiter.allow('c', 1, 1000, 1011), true);
  assert.equal(limiter.allow('b', 1, 1000, 1012), true, 'evicted keys fail open for availability');
});

test('invalid and over-capacity room creates do not spend the shared valid-create allowance', () => {
  const limiter = new FixedWindowLimiter();
  for (let i = 0; i < 20; i++) {
    assert.throws(() => consumeRoomCreationAllowance({ map: 'not-a-map' }, 0, limiter, 100), /Unsupported map/);
    assert.throws(() => consumeRoomCreationAllowance({ map: 'industrial', mode: 'duel' }, 0, limiter, 100), /Unsupported room mode/);
    assert.throws(() => consumeRoomCreationAllowance({ map: 'industrial', time_of_day: 'midnight' }, 0, limiter, 100), /Unsupported time of day/);
  }
  assert.throws(() => consumeRoomCreationAllowance({ map: 'industrial' }, 128, limiter, 100), /capacity reached/);
  assert.deepEqual(consumeRoomCreationAllowance({ map: 'industrial' }, 0, limiter, 100), {
    requested: 'industrial-public', map: 'industrial', requestedMode: 'CONQUEST', timeOfDay: 'noon',
  });
  assert.equal(consumeRoomCreationAllowance({ map: 'arena', mode: 'CONQUEST' }, 0, new FixedWindowLimiter(), 100).requestedMode, 'CONQUEST');
  for (let i = 1; i < 60; i++) consumeRoomCreationAllowance({ map: 'industrial' }, 0, limiter, 100);
  assert.throws(() => consumeRoomCreationAllowance({ map: 'industrial' }, 0, limiter, 100), /rate limited/);
});

test('all public presets force Conquest even for older client mode/map options', () => {
  for (const map of ['industrial', 'resoforge', 'football', 'village', 'arena', 'shipment', 'dust2', 'nuketown', 'canyon', 'desert_oasis']) {
    for (const mode of ['TDM', 'FFA', 'CONQUEST']) {
      const settings = consumeRoomCreationAllowance({ room: `${map}-public`, map: 'industrial', mode }, 0, new FixedWindowLimiter());
      assert.equal(settings.map, map);
      assert.equal(settings.requestedMode, 'CONQUEST');
    }
  }
  assert.equal(consumeRoomCreationAllowance({ room: 'custom-duel', map: 'industrial', mode: 'TDM' }, 0, new FixedWindowLimiter()).requestedMode, 'TDM');
});
