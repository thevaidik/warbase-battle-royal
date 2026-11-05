import { Room, Server } from 'colyseus';
import { MapSchema, Schema, defineTypes } from '@colyseus/schema';
import { WebSocketTransport } from '@colyseus/ws-transport';

class Player extends Schema {
  x = 0; z = 0; username = ''; mode = 'foot'; ack_input_sequence = 0;
}
defineTypes(Player, { x: 'number', z: 'number', username: 'string', mode: 'string', ack_input_sequence: 'number' });
class Car extends Schema {
  x = 0; z = 0; yaw = 0; speed = 0; gear = 1; serial = 37; label = 'CAR_0';
}
defineTypes(Car, { x: 'number', z: 'number', yaw: 'number', speed: 'number', gear: 'number', serial: 'int32', label: 'string' });
class State extends Schema {
  players = new MapSchema<Player>();
  vehicles = new MapSchema<Car>();
}
defineTypes(State, { players: { map: Player }, vehicles: { map: Car } });
class Input extends Schema {
  throttle = 0; steer = 0; gear = 1;
}
defineTypes(Input, { throttle: 'number', steer: 'number', gear: 'number' });

class CompositeRoom extends Room<{ state: State; input: Input }> {
  maxClients = 4;
  inputs = this.defineInput(Input, { bufferMaxSize: 64 });

  onCreate() {
    this.setState(new State());
    // TSX's native class-field emit can bypass legacy schema accessors, so
    // reassign collections through the generated setter before populating.
    this.state.players = new MapSchema();
    this.state.vehicles = new MapSchema();
    const car = new Car();
    car.x = 0; car.z = 0;
    this.state.vehicles.set('CAR_0', car);
    this.setSimulationInterval(() => this.stepServer(), 1000 / 60);
  }

  onJoin(client: any, options: { username?: string }) {
    const player = new Player();
    player.username = options.username ?? client.sessionId;
    this.state.players.set(player.username, player);
  }

  onLeave(client: any) {
    for (const [key, player] of this.state.players) if (player.username === client.sessionId) this.state.players.delete(key);
  }

  private stepServer() {
    const car = this.state.vehicles.get('CAR_0')!;
    for (const client of this.clients) {
      const player = [...this.state.players.values()][0];
      if (!player) continue;
      const input = this.inputs.get(client.sessionId)?.next();
      player.ack_input_sequence = this.inputs.get(client.sessionId)?.consumedCount ?? 0;
      const throttle = input?.throttle ?? 0;
      const steer = input?.steer ?? 0;
      car.gear = input?.gear ?? car.gear;
      car.speed += throttle * 0.24;
      car.yaw += steer * 0.02;
      car.x += Math.sin(car.yaw) * car.speed / 60;
      car.z -= Math.cos(car.yaw) * car.speed / 60;
      player.x = car.x; player.z = car.z; player.mode = 'car';
    }
  }
}

const server = new Server({ transport: new WebSocketTransport(), greet: false });
server.define('composite_probe', CompositeRoom);
await server.listen(18193, '127.0.0.1');
console.log('COMPOSITE_FIXTURE_READY 127.0.0.1:18193');
