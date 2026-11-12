import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import { Server } from 'colyseus';
import { Client } from '@colyseus/sdk';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { query, getLocalRoomById } from '@colyseus/core/MatchMaker';
import { configureBattleAdmission } from './admission.js';
import { configureRealtimeLobby } from './lobby.js';
import { BattleRoom } from './battle-room.js';
import { ConquestQueue } from './conquest-queue.js';
import { GAME_PROTOCOL_VERSION } from './schema.js';
import type { ISeatReservation } from '@colyseus/shared-types';
import { buildRoomDirectory, listLiveBattleRooms } from './room-directory.js';
async function until(check: () => boolean) {
  const deadline = Date.now() + 8000;
  while (!check() && Date.now() < deadline) await new Promise(r => setTimeout(r, 25));
  assert.ok(check(), 'integration lifecycle deadline');
}
test('signed SDK matchmaking, duplicate-session rejection and realtime lobby lifecycle', async t => {
  const socket = createServer();
  await new Promise<void>(r => socket.listen(0, '127.0.0.1', r));
  const port = (socket.address() as { port: number }).port;
  await new Promise<void>(r => socket.close(() => r()));
  const controls = configureBattleAdmission({ secret: 'isolated integration signing secret at least 32 bytes', playerRoomCreateLimit: 1 })!;
  const server = new Server({ transport: new WebSocketTransport(), greet: false, express(app) {
    app.post('/api/admission', controls.issueTicket);
    app.post('/api/rooms', controls.roomCreateMiddleware, (_req, res) => res.json({ ok: true }));
  } });
  configureRealtimeLobby(server, server.define('battle', BattleRoom).filterBy(['room']));
  server.define('conquest_queue', ConquestQueue).filterBy(['map']);
  await server.listen(port, '127.0.0.1');
  const endpoint = `http://127.0.0.1:${port}`;
  const joined: any[] = [];
  t.after(async () => {
    for (const room of joined) await room.leave().catch(() => {});
    await server.gracefullyShutdown(false);
    configureBattleAdmission(undefined);
  });
  const anonymous = new Client(endpoint);
  await assert.rejects(anonymous.joinOrCreate('battle', { protocol_version: 16, username: 'unsigned', room: 'industrial-public' }));
  await assert.rejects(anonymous.joinOrCreate('lobby'));
  assert.equal((await query({ name: 'battle' })).length, 0);
  const ticket = await fetch(`${endpoint}/api/admission`, { method: 'POST' }).then(r => r.json()) as any;
  assert.equal(ticket.expiresIn, 900);
  const client = new Client(endpoint); client.auth.token = ticket.token;
  await assert.rejects(client.joinOrCreate('battle', { protocol_version: 16, username: '<script>', room: 'industrial-public' }));
  assert.equal((await query({ name: 'battle' })).length, 0, 'signed invalid display names rejected before allocation');
  await assert.rejects(client.joinOrCreate('battle', { protocol_version: 8, username: 'old-native', room: 'industrial-public' }), /Game update required/);
  assert.equal((await query({ name: 'battle' })).length, 0, 'old protocol rejected before room creation');
  const lobby = await client.joinOrCreate('lobby'); joined.push(lobby);
  const listings = new Map<string, any>();
  lobby.onMessage('rooms', rooms => { listings.clear(); for (const room of rooms) listings.set(room.roomId, room); });
  lobby.onMessage('+', ([id, room]) => listings.set(id, room));
  lobby.onMessage('-', id => listings.delete(id));
  const battle = await client.joinOrCreate('battle', { protocol_version: 16, username: 'signed-alice', room: 'industrial-public' }); joined.push(battle);
  battle.onMessage('*', () => {});
  await until(() => listings.has(battle.roomId) && listings.get(battle.roomId).clients === 1);
  assert.equal(listings.get(battle.roomId).metadata.mode, 'CONQUEST');
  const duplicate = new Client(endpoint); duplicate.auth.token = ticket.token;
  await assert.rejects(duplicate.joinById(battle.roomId, { protocol_version: 16, username: 'same-identity' }));
  await assert.rejects(client.joinOrCreate('battle', { protocol_version: 16, username: 'quota', room: 'village-public' }));
  assert.equal((await query({ name: 'battle' })).length, 1);
  const directory = buildRoomDirectory(await listLiveBattleRooms());
  assert.equal(directory.rooms.length, 11);
  assert.equal(directory.online_players, 1);
  assert.equal(directory.rooms.find(r => r.id === 'industrial-public')?.playerCount, 1);
  const serverRoom = getLocalRoomById(battle.roomId)!;
  await serverRoom.setMetadata({ ...serverRoom.metadata, timeOfDay: 'noon' });
  await until(() => listings.get(battle.roomId)?.metadata.timeOfDay === 'noon');
  await battle.leave();
  await until(() => listings.get(battle.roomId)?.clients === 0 || !listings.has(battle.roomId));
  await serverRoom.disconnect();
  await until(() => !listings.has(battle.roomId));
  const after = buildRoomDirectory(await listLiveBattleRooms());
  assert.equal(after.online_players, 0);
  assert.equal(after.rooms.length, 11);
  assert.equal((await fetch(`${endpoint}/api/rooms`, { method: 'POST' })).status, 401);

  const queueOptions = (index: number) => ({ map: 'industrial', username: `queue-${index}`, protocol_version: GAME_PROTOCOL_VERSION });
  await assert.rejects(anonymous.joinOrCreate('conquest_queue', queueOptions(0)));
  const queued = await Promise.all(Array.from({ length: 4 }, async (_, index) => {
    const next = new Client(endpoint);
    next.auth.token = (await fetch(`${endpoint}/api/admission`, { method: 'POST' }).then(r => r.json()) as { token: string }).token;
    if (index === 0) {
      const cancelled = await next.joinOrCreate('conquest_queue', queueOptions(index));
      cancelled.onMessage('clients', () => {});
      await cancelled.leave();
    }
    const room = await next.joinOrCreate('conquest_queue', queueOptions(index));
    joined.push(room);
    let seat: ISeatReservation | undefined;
    room.onMessage('seat', value => { seat = value; });
    room.onMessage('clients', () => {});
    return { next, room, getSeat: () => seat };
  }));
  await until(() => queued.every(entry => entry.getSeat() !== undefined));
  const roomIds = new Set(queued.map(entry => entry.getSeat()!.roomId));
  assert.equal(roomIds.size, 1, 'one queue group receives seats in the same match');
  for (const entry of [...queued].reverse()) {
    const match = await entry.next.consumeSeatReservation(entry.getSeat()!);
    match.onMessage('*', () => {});
    joined.push(match);
    entry.room.send('confirm', {});
  }
  const queuedMatch = getLocalRoomById([...roomIds][0]);
  assert.ok(queuedMatch instanceof BattleRoom);
  assert.equal(queuedMatch.state.room_mode, 'CONQUEST');
  const humans = [...queuedMatch.state.players.values()].filter(player => !player.is_bot);
  assert.deepEqual(humans.map(player => player.team).sort(), ['A', 'A', 'B', 'B']);
});
