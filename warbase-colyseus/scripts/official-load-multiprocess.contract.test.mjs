import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeShards } from './official-load-multiprocess.mjs';
const shard = () => ({ roomId: 'one-room', result: 'duration_complete', requested: { sdkPeers: 21 },
  observed: { sdkPeersJoined: 21, nativeObserverVerifiedHuman: true, minLiveClientsDuringMeasurement: 64,
    measurementStartedAt: 1000, measurementEndedAt: 76000, fullOccupancySeconds: 74 },
  lifecycle: { dropsByPhase: { active: 0 }, errors: 0 },
  helperResources: { cpuOneCorePercentMax: 50, eventLoopExcessP95MsMax: 4, samples: [{}] } });
test('independent cohorts require the same room and a complete live roster', () => {
  const rows = [shard(), shard(), shard()];
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, true);
  rows[2].roomId = 'different-room';
  assert.equal(summarizeShards(rows).valid, false);
});
test('unobserved gaps are subtracted conservatively, not averaged', () => {
  const rows = [shard(), shard(), shard()];
  rows[0].observed.fullOccupancySeconds = 65;
  rows[1].observed.fullOccupancySeconds = 65;
  assert.equal(summarizeShards(rows).sharedFullSecondsLowerBound, 54);
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, false);
});
test('helper CPU saturation or missing samples cannot certify latency', () => {
  const rows = [shard(), shard(), shard()];
  rows[1].helperResources.cpuOneCorePercentMax = 95;
  assert.equal(summarizeShards(rows).helperSaturationSuspected, true);
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, false);
  rows[1] = shard(); rows[1].helperResources.samples = [];
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, false);
});
test('transient drops, failed children and partial peer counts cannot pass', () => {
  for (const mutate of [r => r.lifecycle.dropsByPhase.active++, r => r.result = 'failed',
    r => r.observed.sdkPeersJoined--, r => r.observed.nativeObserverVerifiedHuman = false,
    r => r.observed.minLiveClientsDuringMeasurement = 63]) {
    const rows = [shard(), shard(), shard()]; mutate(rows[1]);
    assert.equal(summarizeShards(rows).valid, false);
  }
});

test('event-loop starvation blocks qualification even when helper CPU is low', () => {
  const rows = [shard(), shard(), shard()];
  rows[1].helperResources.eventLoopExcessP95MsMax = 25;
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, false);
  rows[1].helperResources.eventLoopExcessP95MsMax = NaN;
  assert.equal(summarizeShards(rows).capacityEvidenceQualified, false);
});

test('an early observer exit invalidates otherwise clean shard reports', () => {
  const rows = [shard(), shard(), shard()];
  assert.equal(summarizeShards(rows, { observerFinishedEarly: true }).capacityEvidenceQualified, false);
});
