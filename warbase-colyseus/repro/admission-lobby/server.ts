import { Server } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { configureBattleAdmission } from '../../src/admission.js';
import { configureRealtimeLobby } from '../../src/lobby.js';
import { BattleRoom } from '../../src/battle-room.js';
const admission = configureBattleAdmission({ secret: 'isolated loopback-only SDK fixture signing key 32 bytes' })!;
const server = new Server({ transport: new WebSocketTransport(), greet: false, express(app) {
  app.post('/api/admission', admission.issueTicket);
} });
configureRealtimeLobby(server, server.define('battle', BattleRoom).filterBy(['room']));
await server.listen(18301, '127.0.0.1');
console.log('SIGNED_LOBBY_FIXTURE_READY 127.0.0.1:18301');
