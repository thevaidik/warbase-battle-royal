import { Room, Server, type Client } from 'colyseus';
import { ArraySchema, MapSchema, Schema, defineTypes } from '@colyseus/schema';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { BattleState, ObjectiveState, PlayerState, VehicleState } from '../../src/schema.js';

class MoveInput extends Schema {
  move_x = 0; move_z = 0; yaw = 0; pitch = 0; jump = 0; sprint = 0; crouch = 0;
  vehicle_index = -1; vehicle_generation = 0; vehicle_throttle = 0; vehicle_steer = 0;
  vehicle_brake = 0; vehicle_gear = 1;
}
defineTypes(MoveInput, {
  move_x: 'number', move_z: 'number', yaw: 'number', pitch: 'number', jump: 'number', sprint: 'number', crouch: 'number',
  vehicle_index: 'number', vehicle_generation: 'number', vehicle_throttle: 'number', vehicle_steer: 'number',
  vehicle_brake: 'number', vehicle_gear: 'number',
});

class IncrementalRoom extends Room<{ state: BattleState; input: MoveInput }> {
  inputs = this.defineInput(MoveInput, { bufferMaxSize: 64 });
  private readonly usernames = new Map<string, string>();

  onCreate() {
    const state = new BattleState();
    state.players = new MapSchema();
    state.vehicles = new MapSchema();
    state.objectives = new MapSchema();
    state.protocol_version = 6;
    state.map_name = 'industrial';
    const vehicle = new VehicleState();
    vehicle.id = 'CAR_TEST';
    vehicle.pos[0] = 1;
    vehicle.pos[1] = 2;
    vehicle.pos[2] = 3;
    state.vehicles.set(vehicle.id, vehicle);
    const objective = new ObjectiveState();
    objective.id = 'A';
    objective.progress = 0.125;
    state.objectives.set(objective.id, objective);
    this.setState(state);
    (this as any)._serializer?.encoder?.discardChanges?.();

    this.onMessage('qa_patch', (_client: Client, payload: { target: string }) => {
      this.state.score_a += 1;
      this.state.tickets_a -= 1;
      const player = this.state.players.get(payload.target);
      if (player) {
        player.health = 87;
        player.x = 11;
        player.animation = 'run';
      }
      const point = this.state.objectives.get('A');
      if (point) point.progress = 0.375;
    });
    this.onMessage('qa_vehicle_array', () => {
      const car = this.state.vehicles.get('CAR_TEST');
      if (car) {
        car.pos[0] = 12;
        car.pos[1] = 2;
        car.pos[2] = 34;
      }
    });
    this.onMessage('qa_root_patch', () => {
      this.state.score_a += 1;
      this.state.tickets_a -= 1;
    });
  }


  onJoin(client: Client, options: { username?: string }) {
    const player = new PlayerState();
    player.username = options.username ?? 'unnamed';
    this.state.players.set(player.username, player);
    this.usernames.set(client.sessionId, player.username);
  }

  onLeave(client: Client) {
    const username = this.usernames.get(client.sessionId);
    this.usernames.delete(client.sessionId);
    for (const [key, player] of this.state.players) {
      if (player.username === username) this.state.players.delete(key);
    }
  }
}

const server = new Server({ transport: new WebSocketTransport(), greet: false });
server.define('battle', IncrementalRoom);
await server.listen(18196, '127.0.0.1');
console.log('INCREMENTAL_STATE_FIXTURE_READY 127.0.0.1:18196');
