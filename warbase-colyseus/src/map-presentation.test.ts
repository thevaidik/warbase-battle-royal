import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { buildRoomDirectory, OFFICIAL_MAP_NAMES } from './room-directory.js';
import { loadWorldGeometry, PLAYABLE_MAPS, type Vec3 } from './world-geometry.js';

test('match names are independent of canonical map names in both public and custom listings', () => {
  const directory = buildRoomDirectory([{id:'id', room:'custom', name:'Industrial Outpost', map:'canyon',mode:'CONQUEST',timeOfDay:'noon',clients:1,bots:0,maxClients:64}]);
  assert.equal(directory.rooms.find(x => x.id==='custom')?.mapName,'Devil’s Canyon');
  assert.equal(directory.rooms.find(x => x.id==='custom')?.name,'Industrial Outpost');
  assert.equal(directory.rooms.find(x => x.id==='canyon-public')?.name,'Public Conquest');
  const menu=readFileSync(new URL('../../warbase-godot/client/scripts/ui/MainMenu.gd',import.meta.url),'utf8');
  for(const [id,name]of Object.entries(OFFICIAL_MAP_NAMES))assert.ok(menu.includes(`"${id}":"${name}"`),`canonical map label ${id}`);
});

test('restored maps have distinct source geometry rather than Industrial variants', () => {
  const industrial = loadWorldGeometry('industrial')!;
  for (const id of ['dust2','canyon','military_base']) {
    const map = loadWorldGeometry(id)!;
    assert.notEqual(map.spawns[0].join(','), industrial.spawns[0].join(','), id);
    assert.equal(map.spawns.length, 12);
  }
});

test('every shipped authoritative spawn has at least two clear walking exits', () => {
  let checked = 0;
  for (const map of PLAYABLE_MAPS) {
    const geometry = loadWorldGeometry(map)!;
    for (const from of geometry.spawns) {
      let exits = 0;
      for (const [dx,dz] of [[0.5,0],[-0.5,0],[0,0.5],[0,-0.5]]) {
        const moved = geometry.resolveMove(from,[from[0]+dx,from[1],from[2]+dz]);
        if (Math.hypot(moved[0]-from[0],moved[2]-from[2]) >= 0.49) exits++;
      }
      assert.ok(exits >= 2, `${map}: trapped authoritative spawn ${from}`);
      checked++;
    }
  }
  assert.equal(checked,PLAYABLE_MAPS.length * 12);
});
