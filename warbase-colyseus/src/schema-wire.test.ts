import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { Decoder, Encoder, Metadata, StateView } from '@colyseus/schema';
import { BattleState, PlayerState, VehicleState, ObjectiveState, PRIVATE_VIEW_TAG, PRESENTATION_VIEW_TAG } from './schema.js';
import { PLAYABLE_MAPS } from './world-geometry.js';

function encodeFull(encoder: Encoder, view: StateView): Uint8Array {
  const it = { offset: 0 }; encoder.encodeAll(it);
  return encoder.encodeAllView(view, it.offset, it).slice();
}
function encodePatch(encoder: Encoder, view: StateView): Uint8Array {
  const it = { offset: 0 }; encoder.encode(it);
  return encoder.encodeView(view, it.offset, it).slice();
}
test('compact fields preserve authoritative doubles and decode at float32 precision', () => {
  const state = new BattleState(), player = new PlayerState(), car = new VehicleState();
  state.players.set('alice', player); state.vehicles.set('car', car);
  const value = -123.123456789;
  player.x = value; player.yaw = 1.123456789; player.pose_time_ms = 1793902661906;
  car.x = value; car.y = 1.123456789; car.z = 77.123456789;
  const encoder = new Encoder(state), view = new StateView();
  view.add(player, PRIVATE_VIEW_TAG); view.add(player, PRESENTATION_VIEW_TAG);
  const decoded = new BattleState(); new Decoder(decoded).decode(encodeFull(encoder, view));
  assert.equal(player.x, value, 'wire format never quantizes authoritative simulation');
  assert.equal(decoded.players.get('alice')!.x, Math.fround(value));
  assert.equal(decoded.players.get('alice')!.pose_time_ms, 1793902661906, 'wall timestamps must not lose precision');
  assert.equal(decoded.vehicles.get('car')!.x, Math.fround(value));
  assert.equal(Object.hasOwn(decoded.vehicles.get('car')!.toJSON(), 'pos'), false, 'only scalar vehicle coordinates are serialized');
  view.dispose();
});
test('rotation remains in authoritative rewind state but is not repeated in live patches', () => {
  const state = new BattleState(), player = new PlayerState(); state.players.set('alice', player);
  const encoder = new Encoder(state), view = new StateView(); view.add(player, PRIVATE_VIEW_TAG); view.add(player, PRESENTATION_VIEW_TAG);
  const decoded = new BattleState(), decoder = new Decoder(decoded); decoder.decode(encodeFull(encoder, view)); encoder.discardChanges();
  player.qy = Math.sin(0.5); player.qw = Math.cos(0.5); player.yaw = 1;
  decoder.decode(encodePatch(encoder, view));
  assert.equal(decoded.players.get('alice')!.yaw, 1);
  assert.equal(decoded.players.get('alice')!.qy, 0, 'full-state-only rotation is not resent');
  assert.equal(player.qy, Math.sin(0.5), 'server rotation retains exact precision');
  view.dispose();
});
test('all map coordinate ranges fit a sub-millimetre float32 delivery budget', () => {
  for (const map of PLAYABLE_MAPS) {
    const data = JSON.parse(gunzipSync(readFileSync(new URL(`./data/maps/${map}.json.gz`, import.meta.url))).toString());
    let maximum = 1;
    for (const value of data.triangles) maximum = Math.max(maximum, Math.abs(value));
    for (const spawn of data.spawns) for (const value of spawn) maximum = Math.max(maximum, Math.abs(value));
    const worstHalfUlp = 2 ** (Math.floor(Math.log2(maximum)) - 24);
    assert.ok(worstHalfUlp <= 0.001, `${map}: coordinate budget exceeds one millimetre`);
  }
});
test('Godot concrete field order and wire types match every server schema', () => {
  const source = readFileSync(new URL('../../warbase-godot/client/scripts/net/ColyseusSchema.gd', import.meta.url), 'utf8');
  for (const [name, Type] of Object.entries({ PlayerState, VehicleState, ObjectiveState, RoomState: BattleState })) {
    const section = source.split(`class ${name} extends Colyseus.Schema:`)[1]!.split(/\nclass |\nstatic func/)[0];
    const fields = [...section.matchAll(/Field.new\("([^"]+)", Colyseus.Schema.([A-Z0-9_]+)/g)].map(m => [m[1], m[2].toLowerCase()]);
    const metadata = Metadata.getFields(Type);
    const server = Object.entries(metadata).map(([field, descriptor]: [string, any]) => [field, typeof descriptor === 'string' ? descriptor : 'map']);
    assert.deepEqual(fields, server, `${name} field order/types differ`);
  }
});
