import { Room, Server, type Client } from 'colyseus';
import { MapSchema, Schema, StateView, defineTypes } from '@colyseus/schema';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { BattleState, ObjectiveState, PlayerState, VehicleState, PRIVATE_VIEW_TAG, PRESENTATION_VIEW_TAG } from '../../src/schema.js';

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
    state.protocol_version = 9;
    state.map_name = 'industrial';
    const vehicle = new VehicleState();
    vehicle.id = 'CAR_TEST';
    vehicle.x = 1;
    vehicle.y = 2;
    vehicle.z = 3;
    state.vehicles.set(vehicle.id, vehicle);
    const objective = new ObjectiveState();
    objective.id = 'A';
    objective.progress = 0.125;
    state.objectives.set(objective.id, objective);
    this.setState(state);
    this.setFixedTimestep(() => { for (const client of this.clients) this.inputs.get(client.sessionId).next(); }, 60);
    (this as any)._serializer?.encoder?.discardChanges?.();

    this.onMessage('state_meta', () => {});
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
    this.onMessage('qa_vehicle_scalars', () => {
      const car = this.state.vehicles.get('CAR_TEST');
      if (car) {
        car.x = 12;
        car.y = 2;
        car.z = 34;
      }
    });
    this.onMessage('qa_prediction_mode', (client, payload: { driving: boolean }) => {
      const player = this.state.players.get(this.usernames.get(client.sessionId) ?? '');
      const car = this.state.vehicles.get('CAR_TEST');
      if (!player || !car) return;
      player.vehicle_index = payload.driving ? 0 : -1;
      player.vehicle_generation++;
      player.driving_vehicle = payload.driving ? car.id : '';
      car.driver = payload.driving ? player.username : '';
    });
    this.onMessage('qa_root_patch', () => {
      this.state.score_a += 1;
      this.state.tickets_a -= 1;
    });
  }


  onJoin(client: Client, options: { username?: string }) {
    if (options.username?.startsWith("Reject_")) throw new Error("Expected fixture rejection");
    const player = new PlayerState();
    player.username = options.username ?? 'unnamed';
    this.state.players.set(player.username, player);
    this.usernames.set(client.sessionId, player.username);
    const socket = (client as any).ref;
    socket?.on('close', (code: number, reason: Buffer) => console.log('QA_SOCKET_CLOSE', player.username, code, reason.toString()));
    client.view = new StateView();
    client.view.add(player, PRIVATE_VIEW_TAG);
    for (const peer of this.clients) for (const target of this.state.players.values()) peer.view?.add(target, PRESENTATION_VIEW_TAG);
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
