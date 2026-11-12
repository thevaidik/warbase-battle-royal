import test from 'node:test';
import assert from 'node:assert/strict';
import { configureRealtimeLobby } from './lobby.js';

test('configures official realtime lobby and enables battle listing', () => {
  let listingEnabled = false;
  let lobbyDefinition: unknown;
  const battle = { enableRealtimeListing() { listingEnabled = true; return this; } } as any;
  const server = { define(name: string, definition: unknown) { lobbyDefinition = { name, definition }; return this; } } as any;

  configureRealtimeLobby(server, battle);

  assert.equal(listingEnabled, true);
  assert.equal((lobbyDefinition as { name: string }).name, 'lobby');
  assert.ok((lobbyDefinition as { definition: unknown }).definition);
});
