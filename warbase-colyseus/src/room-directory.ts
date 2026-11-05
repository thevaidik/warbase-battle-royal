import { query } from '@colyseus/core/MatchMaker';
import { PLAYABLE_MAPS } from './world-geometry.js';

const names: Record<string, string> = {
  industrial: 'Industrial Zone (Public)', resoforge: 'ResoForge Yard (Public)', football: 'Football Stadium (Public)',
  village: 'Village Outpost (Public)', arena: 'Game Arena (Public)', shipment: 'Shipment (Public)',
  dust2: 'Industrial Recon (Public)', canyon: 'Canyon (Public)', desert_oasis: 'Desert Oasis (Public)', nuketown: 'Industrial Outpost (Public)',
};

/** Read the framework driver, so HTTP fallback and realtime lobby agree even
 * when the optional Redis driver owns rooms on another worker. */
export async function listLiveBattleRooms() {
  const cached = await query({ name: 'battle', private: false });
  return cached.filter(room => PLAYABLE_MAPS.includes(room.metadata?.map)).map(room => ({
    id: room.roomId,
    room: String(room.metadata.room), name: String(room.metadata.name), map: String(room.metadata.map),
    mode: String(room.metadata.mode), timeOfDay: String(room.metadata.timeOfDay),
    clients: room.clients, bots: Number(room.metadata.botCount ?? 0), maxClients: room.maxClients,
  }));
}

export function buildRoomDirectory(live: Awaited<ReturnType<typeof listLiveBattleRooms>>) {
  const defaults = PLAYABLE_MAPS.map(map => {
    const id = `${map}-public`;
    const room = live.find(item => item.room === id);
    return { id, name: room?.name ?? names[map], map, mode: 'CONQUEST', playerCount: room?.clients ?? 0,
      botCount: room?.bots ?? 0, capacity: 64, timeOfDay: room?.timeOfDay ?? 'dusk' };
  });
  const custom = live.filter(room => !PLAYABLE_MAPS.some(map => room.room === `${map}-public`)).map(room => ({
    id: room.room, name: room.name, map: room.map, mode: room.mode, playerCount: room.clients,
    botCount: room.bots, capacity: room.maxClients, timeOfDay: room.timeOfDay,
  }));
  const rooms = [...defaults, ...custom].sort((a, b) => b.playerCount - a.playerCount || a.name.localeCompare(b.name));
  return { online_players: live.reduce((sum, room) => sum + room.clients, 0), rooms };
}
