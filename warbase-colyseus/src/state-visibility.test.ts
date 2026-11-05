import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import { Server } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { ColyseusTestServer } from '@colyseus/testing';
import { BattleRoom } from './battle-room.js';

async function waitFor(condition: () => boolean) {
  const deadline = Date.now() + 6000;
  while (!condition() && Date.now() < deadline) await new Promise(r => setTimeout(r, 20));
  assert.ok(condition(), 'state/lifecycle deadline');
}

test('battle StateView preserves public peers and private owner fields across reconnect/removal', async t => {
  const socket = createServer();
  await new Promise<void>(resolve => socket.listen(0, '127.0.0.1', resolve));
  const port = (socket.address() as { port: number }).port;
  await new Promise<void>(resolve => socket.close(() => resolve()));
  const server = new Server({ transport: new WebSocketTransport(), greet: false });
  server.define('battle', BattleRoom).filterBy(['room']);
  await server.listen(port, '127.0.0.1');
  const testing = new ColyseusTestServer(server);
  t.after(async () => { await testing.cleanup(); await testing.shutdown(); });
  const room = await testing.createRoom<BattleRoom>('battle', { room: 'industrial-public' });
  const a = await testing.connectTo(room, { username: 'view-alice' });
  const b = await testing.connectTo(room, { username: 'view-bob' });
  a.onMessage('*', () => {}); b.onMessage('*', () => {});
  await waitFor(() => !!a.state?.players?.has('view-bob') && !!b.state?.players?.has('view-alice'));
  const alice = room.state.players.get('view-alice')!;
  const bob = room.state.players.get('view-bob')!;
  alice.ammo = 17; bob.ammo = 21;
  alice.grenades = 1; alice.throwable = 'impact';
  alice.ack_input_sequence = 47;
  await waitFor(() => a.state.players.get('view-alice')?.ammo === 17 && b.state.players.get('view-bob')?.ammo === 21);
  const verify = () => {
    assert.equal(a.state.players.get('view-alice')?.ammo, 17);
    assert.equal(a.state.players.get('view-alice')?.grenades, 1);
    assert.equal(a.state.players.get('view-alice')?.throwable, 'impact');
    assert.equal(typeof a.state.players.get('view-alice')?.ack_input_sequence, 'number');
    for (const field of ['ammo', 'grenades', 'throwable', 'ack_input_sequence']) {
      assert.equal((a.state.players.get('view-bob') as any)?.[field], undefined, `peer ${field} leaked`);
      assert.equal((b.state.players.get('view-alice') as any)?.[field], undefined, `peer ${field} leaked`);
    }
    assert.equal(a.state.players.get('view-bob')?.username, 'view-bob');
    assert.equal(b.state.players.get('view-alice')?.username, 'view-alice');
    assert.equal(typeof b.state.players.get('view-alice')?.x, 'number');
  };
  verify();
  a.reconnection.minUptime = 0;
  let reconnected = false;
  a.onReconnect.once(() => { reconnected = true; });
  a.connection.close();
  await waitFor(() => reconnected && a.state.players.get('view-alice')?.ammo === 17);
  verify();
  await b.leave();
  await waitFor(() => !a.state.players.has('view-bob'));
  await a.leave();
});
