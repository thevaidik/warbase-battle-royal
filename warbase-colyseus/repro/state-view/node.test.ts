import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import test from 'node:test';
import { ColyseusTestServer } from '@colyseus/testing';
import { makeProbeServer } from './server.js';

const waitFor = async (condition: () => boolean, message: string, timeoutMs = 5000) => {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (condition()) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert.fail(message);
};

async function availablePort(): Promise<number> {
  const socket = createServer();
  await new Promise<void>((resolve, reject) => socket.listen(0, '127.0.0.1', resolve).once('error', reject));
  const address = socket.address();
  if (!address || typeof address === 'string') throw new Error('No loopback port available');
  const port = address.port;
  await new Promise<void>((resolve, reject) => socket.close((error) => error ? reject(error) : resolve()));
  return port;
}

test('unfiltered baseline and two-peer StateView ownership/reconnect/removal', async (t) => {
  const server = makeProbeServer();
  await server.listen(await availablePort(), '127.0.0.1');
  const testing = new ColyseusTestServer(server);
  t.after(async () => { await testing.cleanup(); await testing.shutdown(); });

  await t.test('unfiltered baseline exposes the owner field to both peers', async () => {
    const room = await testing.createRoom('state_view_probe', { filtered: false });
    const alice = await testing.connectTo(room, { name: 'alice' });
    const bob = await testing.connectTo(room, { name: 'bob' });
    t.after(async () => { await Promise.allSettled([alice.leave(), bob.leave()]); });
    await waitFor(() => alice.state?.players?.has('bob') && bob.state?.players?.has('alice'), 'baseline peers did not receive initial state');
    assert.equal(alice.state.players.get('alice')?.ownerSecret, 'secret:alice');
    assert.equal(alice.state.players.get('bob')?.ownerSecret, 'secret:bob');
    assert.equal(bob.state.players.get('alice')?.ownerSecret, 'secret:alice');
    await alice.leave(); await bob.leave();
  });

  await t.test('tagged owner field is private; reconnect keeps ownership and leave removes the peer', async () => {
    const room = await testing.createRoom('state_view_probe', { filtered: true });
    const alice = await testing.connectTo(room, { name: 'alice' });
    const bob = await testing.connectTo(room, { name: 'bob' });
    t.after(async () => { await Promise.allSettled([alice.leave(), bob.leave()]); });
    await waitFor(() => alice.state?.players?.has('bob') && bob.state?.players?.has('alice'), 'filtered peers did not receive public initial state');
    assert.equal(alice.state.players.get('alice')?.ownerSecret, 'secret:alice', 'owner sees own tagged field');
    assert.equal(alice.state.players.get('bob')?.ownerSecret, undefined, 'non-owner cannot see peer tagged field');
    assert.equal(bob.state.players.get('bob')?.ownerSecret, 'secret:bob', 'second owner sees own tagged field');
    assert.equal(bob.state.players.get('alice')?.ownerSecret, undefined, 'second non-owner cannot see peer tagged field');

    const reconnected = new Promise<void>((resolve) => alice.onReconnect.once(resolve));
    alice.reconnection.minUptime = 0;
    alice.connection.close();
    await Promise.race([reconnected, new Promise<never>((_, reject) => setTimeout(() => reject(new Error('automatic reconnect timed out')), 7000))]);
    await waitFor(() => alice.state?.players?.get('alice')?.ownerSecret === 'secret:alice', 'owner view missing after reconnect');
    assert.equal(alice.state.players.get('bob')?.ownerSecret, undefined, 'non-owner remains filtered after reconnect');

    await bob.leave();
    await waitFor(() => !alice.state?.players?.has('bob'), 'peer removal did not reach remaining client');
    await alice.leave();
  });
});
