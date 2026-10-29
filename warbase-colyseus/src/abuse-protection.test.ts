import assert from 'node:assert/strict';
import test from 'node:test';
import { canonicalizeUsername, FixedWindowLimiter } from './abuse-protection.js';

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
