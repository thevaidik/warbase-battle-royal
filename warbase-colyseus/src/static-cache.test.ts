import test from 'node:test';
import assert from 'node:assert/strict';
import { assetCacheControl } from './static-cache.js';

test('HTML revalidates when included in the release manifest, including directory index responses', () => {
  assert.equal(assetCacheControl('index.html', new Set(['index.html']), new Set()), 'no-cache');
  assert.equal(assetCacheControl('help.html', new Set(['help.html']), new Set()), 'no-cache');
});
test('fixed SDK runtime paths revalidate while content-addressed assets remain immutable', () => {
  const assets = new Set(['engine-123abc.wasm', 'sdk-runtime.wasm']);
  const mutable = new Set(['sdk-runtime.wasm']);
  assert.equal(assetCacheControl('sdk-runtime.wasm', assets, mutable), 'no-cache');
  assert.equal(assetCacheControl('engine-123abc.wasm', assets, mutable), 'public, max-age=31536000, immutable');
});
test('development assets keep bounded caching without a release manifest', () => {
  const empty = new Set<string>();
  assert.equal(assetCacheControl('index.js', empty, empty), 'no-cache');
  assert.equal(assetCacheControl('game.wasm', empty, empty), 'public, max-age=300');
  assert.equal(assetCacheControl('image.png', empty, empty), undefined);
});
