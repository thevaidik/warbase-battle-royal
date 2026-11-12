import { Server, type Client } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { BattleRoom } from '../../src/battle-room.js';

class MainVehicleRoom extends BattleRoom {
  override onCreate(options: any) {
    super.onCreate(options);
    // Loopback-only fixture action. Not part of the production room protocol.
    this.onMessage('qa_kill_driver', (client: Client) => {
      const username = (this as any).internal.get(client.sessionId)?.username;
      const player = this.state.players.get(username);
      if (player) (this as any).killPlayer(undefined, player);
    });
  }
  override onJoin(client: Client, options: any, auth?: { username: string }) {
    super.onJoin(client, options, auth);
    const username = auth?.username ?? String(options?.username ?? '');
    const player = this.state.players.get(username);
    const vehicle = (this as any).vehicleSimulation.states.get('CAR_0');
    const runtime = (this as any).internal.get(client.sessionId);
    if (!player || !vehicle || !runtime) throw new Error('Main vehicle fixture could not initialize CAR_0 admission');
    // Put the real BattleRoom player inside enter range with a clear, zero-length ray.
    player.x = vehicle.pos[0]; player.y = vehicle.pos[1]; player.z = vehicle.pos[2];
    // Avoid bot-fire timing affecting a bounded, test-only live vehicle run.
    runtime.protectedUntil = Date.now() + 60_000;
  }
}

const server = new Server({ transport: new WebSocketTransport(), greet: false });
server.define('battle', MainVehicleRoom);
await server.listen(18195, '127.0.0.1');
console.log('MAIN_VEHICLE_FIXTURE_READY 127.0.0.1:18195');
