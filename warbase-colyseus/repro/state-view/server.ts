import { existsSync } from 'node:fs';
import { Server, Room } from 'colyseus';
import { existsSync } from 'node:fs';
import { StateView, schema, t } from '@colyseus/schema';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { createRoom } from '@colyseus/core/MatchMaker';

export const BaselinePlayer = schema({ name: t.string(), publicValue: t.string(), ownerSecret: t.string() }, 'StateViewBaselinePlayer');
export const FilteredPlayer = schema({ name: t.string(), publicValue: t.string(), ownerSecret: t.string().view() }, 'StateViewProbePlayer');
export const BaselineState = schema({ players: t.map(BaselinePlayer), protocol: t.string() }, 'StateViewBaselineState');
export const FilteredState = schema({ players: t.map(FilteredPlayer), protocol: t.string() }, 'StateViewProbeState');

export class StateViewProbeRoom extends Room<{ state: any }> {
  state: any = new BaselineState();

  onCreate(options: { filtered?: boolean }) {
    this.autoDispose = false;
    this.setState(options.filtered ? new FilteredState() : new BaselineState());
    this.setMetadata({ filtered: options.filtered === true });
    this.state.protocol = options.filtered ? 'state-view-v1' : 'unfiltered-v1';
    this.onMessage('change', (client, value: string) => {
      const name = String(client.userData?.name ?? '');
      const player = this.state.players.get(name);
      if (player) player.publicValue = String(value);
    });
  }

  onJoin(client: any, options: { name?: string }) {
    const name = String(options.name ?? '').trim();
    if (!name) throw new Error('name required');
    const Player = this.state.protocol === 'state-view-v1' ? FilteredPlayer : BaselinePlayer;
    const player = new Player().assign({ name, publicValue: `public:${name}`, ownerSecret: `secret:${name}` });
    this.state.players.set(name, player);
    client.userData = { name };
    if (this.state.protocol === 'state-view-v1') {
      client.view = new StateView();
      client.view.add(player);
    }
  }

  async onDrop(client: any) {
    try { await this.allowReconnection(client, 15); } catch { /* Expired sessions are removed by onLeave. */ }
  }

  onLeave(client: any) {
    const player = this.state.players.get(String(client.userData?.name ?? ''));
    if (!player) return;
    for (const peer of this.clients) peer.view?.remove(player);
    this.state.players.delete(player.name);
  }
}

export function makeProbeServer() {
  const server = new Server({ transport: new WebSocketTransport(), greet: false });
  server.define('state_view_probe', StateViewProbeRoom);
  return server;
}

if (process.argv[1] && existsSync(process.argv[1]) && process.argv[1].endsWith('server.ts')) {
  const port = Number(process.env.STATE_VIEW_PORT ?? 8097);
  const server = makeProbeServer();
  await server.listen(port, '127.0.0.1');
  console.log(`STATE_VIEW_PROBE_LISTENING ws://127.0.0.1:${port}`);
  const filtered = process.env.STATE_VIEW_FILTERED !== 'false';
  const room = await createRoom('state_view_probe', { filtered });
  console.log(`STATE_VIEW_PROBE_ROOM_ID=${room.roomId} filtered=${filtered}`);
}
