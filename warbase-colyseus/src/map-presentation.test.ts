import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { buildRoomDirectory, OFFICIAL_MAP_NAMES } from './room-directory.js';
import { loadWorldGeometry, PLAYABLE_MAPS, type Vec3 } from './world-geometry.js';

test('match names are independent of canonical map names in both public and custom listings', () => {
  const directory = buildRoomDirectory([{id:'id', room:'custom', name:'Industrial Outpost', map:'canyon',mode:'CONQUEST',timeOfDay:'noon',clients:1,bots:0,maxClients:64}]);
  assert.equal(directory.rooms.find(x => x.id==='custom')?.mapName,'Canyon');
  assert.equal(directory.rooms.find(x => x.id==='custom')?.name,'Industrial Outpost');
  assert.equal(directory.rooms.find(x => x.id==='canyon-public')?.name,'Public Conquest');
  const menu=readFileSync(new URL('../../warbase-godot/client/scripts/ui/MainMenu.gd',import.meta.url),'utf8');
  for(const [id,name]of Object.entries(OFFICIAL_MAP_NAMES))assert.ok(menu.includes(`"${id}":"${name}"`),`canonical map label ${id}`);
});

test('Desert Oasis former invisible boundaries are open and visible outer rocks stop movement', () => {
  const g=loadWorldGeometry('desert_oasis')!;
  for(const [x,z]of [[1,0],[-1,0],[0,1],[0,-1]]){
    assert.equal(g.rayBlocked([x*30,1,z*30],[x*35,1,z*35]),false,'former hidden square');
    assert.equal(g.rayBlocked([x*35,1,z*35],[x*42,1,z*42]),true,'visible rock boundary');
  }
});

test('all repaired desert and canyon spawns allow movement in all four directions', () => {
  for(const map of ['desert_oasis','canyon']){
    const g=loadWorldGeometry(map)!;
    for(const spawn of g.spawns)for(const [dx,dz]of [[0.1,0],[-0.1,0],[0,0.1],[0,-0.1]]){
      const to: Vec3=[spawn[0]+dx,spawn[1],spawn[2]+dz];
      const moved=g.resolveMove(spawn,to);
      assert.ok(Math.abs(moved[0]-to[0])<1e-7&&Math.abs(moved[2]-to[2])<1e-7,`${map} embedded spawn ${spawn}`);
    }
  }
  const canyon=loadWorldGeometry('canyon')!;
  assert.ok(Math.abs(canyon.floorHeight(-28,-28,2)!)<1e-6);
  assert.equal(canyon.rayBlocked([35,1,0],[46,1,0]),true,'visible canyon cliff');
  assert.ok(canyon.spawns.every(p=>Math.abs(p[0])<=28&&Math.abs(p[2])<=28));
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
  assert.equal(checked,120);
});
