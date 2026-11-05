// Bounded paired-release check using ordinary public-room joins. No state writes.
import assert from 'node:assert/strict';
import { Client } from '@colyseus/sdk';
const endpoint = process.argv[2] || 'https://war.vaidik.blog/colyseus';
const url = new URL(endpoint);
assert.ok(endpoint === 'https://war.vaidik.blog/colyseus' || (['127.0.0.1', 'localhost'].includes(url.hostname) && url.protocol === 'http:'), 'Only official or loopback staging endpoints are allowed');
const joined = [];
const until = async (check, label) => {
  const deadline = Date.now() + 12000;
  while (!check() && Date.now() < deadline) await new Promise(r => setTimeout(r, 30));
  assert.ok(check(), label);
};
const admittedClient = async () => {
  const response = await fetch(endpoint + '/api/admission', { method: 'POST' });
  assert.equal(response.status, 200, 'ticket issuer');
  const ticket = await response.json();
  assert.ok(ticket.token && ticket.playerId);
  const client = new Client(endpoint); client.auth.token = ticket.token;
  return client;
};
try {
  assert.equal((await fetch(endpoint + '/health')).status, 200);
  const html = await fetch(endpoint + '/', { method: 'HEAD' });
  assert.equal(html.status, 200);
  assert.match(html.headers.get('cache-control') || '', /no-cache/, 'HTML must revalidate across releases');
  const clients = [await admittedClient(), await admittedClient()];
  const rooms = new Map();
  const lobby = await clients[0].joinOrCreate('lobby'); joined.push(lobby);
  lobby.onMessage('rooms', list => { rooms.clear(); for (const room of list) rooms.set(room.roomId, room); });
  lobby.onMessage('+', ([id, room]) => rooms.set(id, room));
  lobby.onMessage('-', id => rooms.delete(id));
  const suffix = Date.now().toString(36);
  const names = ['ReleaseCheckA_' + suffix, 'ReleaseCheckB_' + suffix];
  const a = await clients[0].joinOrCreate('battle', { room: 'industrial-public', username: names[0] }); joined.push(a);
  a.onMessage('*', () => {});
  const b = await clients[1].joinOrCreate('battle', { room: 'industrial-public', username: names[1] }); joined.push(b);
  b.onMessage('*', () => {});
  assert.equal(a.roomId, b.roomId, 'both peers share a room');
  await until(() => a.state?.players?.has(names[1]) && b.state?.players?.has(names[0]), 'public peers visible');
  const verify = () => {
    for (const [owner, own, peer] of [[a, names[0], names[1]], [b, names[1], names[0]]]) {
      assert.equal(typeof owner.state.players.get(own).ammo, 'number');
      for (const field of ['ammo', 'grenades', 'throwable', 'ack_input_sequence']) assert.equal(owner.state.players.get(peer)[field], undefined, 'peer private field: ' + field);
      assert.equal(typeof owner.state.players.get(peer).x, 'number');
    }
    assert.equal(a.state.room_mode, 'CONQUEST');
    assert.equal(a.state.objectives.size, 4);
  };
  verify();
  await until(() => rooms.get(a.roomId)?.clients >= 2, 'realtime lobby occupancy');
  const directory = await fetch(endpoint + '/api/rooms').then(r => r.json());
  assert.ok(directory.rooms.some(r => r.id === 'industrial-public' && r.playerCount >= 2));
  a.reconnection.minUptime = 0;
  let reconnected = false;
  a.onReconnect.once(() => { reconnected = true; });
  a.connection.close();
  await until(() => reconnected && a.state?.players?.has(names[1]), 'native-compatible reconnect path');
  verify();
  await b.leave();
  await until(() => !a.state.players.has(names[1]), 'peer removal');
  console.log('RELEASE_SDK_OK signed_join=true lobby=true privacy=true conquest=true reconnect=true removal=true');
} finally {
  for (const room of joined.reverse()) await room.leave().catch(() => {});
}
