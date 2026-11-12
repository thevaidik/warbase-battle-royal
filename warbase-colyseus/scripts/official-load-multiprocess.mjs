#!/usr/bin/env node
/** Separate SDK decoders across OS processes, while keeping the official game path. */
import { fork, spawn } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { prepareAdmissionTickets } from './official-load-harness.mjs';

const ENDPOINT = 'https://war.vaidik.blog/colyseus';
const HARNESS = fileURLToPath(new URL('./official-load-harness.mjs', import.meta.url));

export function summarizeShards(reports, { observerFinishedEarly = false } = {}) {
  if (!reports.length) return { valid: false, reason: 'no shard reports' };
  const roomIds = new Set(reports.map(r => r.roomId));
  const first = Math.max(...reports.map(r => r.observed.measurementStartedAt));
  const last = Math.min(...reports.map(r => r.observed.measurementEndedAt));
  const interval = Math.max(0, (last - first) / 1000);
  // Subtract every shard's unproven interval: conservative even when gaps overlap.
  const deficits = reports.reduce((sum, r) => sum + Math.max(0,
    (r.observed.measurementEndedAt - r.observed.measurementStartedAt) / 1000 - r.observed.fullOccupancySeconds), 0);
  const sharedFullSecondsLowerBound = Math.max(0, interval - deficits);
  const joined = reports.reduce((sum, r) => sum + r.observed.sdkPeersJoined, 0);
  const valid = !observerFinishedEarly && roomIds.size === 1 && Boolean(reports[0].roomId) && joined === 63 && first > 0 &&
    reports.every(r => r.result === 'duration_complete' && r.observed.minLiveClientsDuringMeasurement === 64 &&
      r.observed.nativeObserverVerifiedHuman && r.lifecycle.dropsByPhase.active === 0 && r.lifecycle.errors === 0 &&
      r.observed.sdkPeersJoined === r.requested.sdkPeers);
  const maxHelperCpuPercent = Math.max(...reports.map(r => r.helperResources.cpuOneCorePercentMax));
  const maxHelperLoopExcessP95Ms = Math.max(...reports.map(r => r.helperResources.eventLoopExcessP95MsMax));
  const helperSamplesPresent = reports.every(r => r.helperResources.samples.length > 0);
  const helperSaturationSuspected = !helperSamplesPresent || !Number.isFinite(maxHelperCpuPercent) ||
    maxHelperCpuPercent >= 90 || !Number.isFinite(maxHelperLoopExcessP95Ms) || maxHelperLoopExcessP95Ms > 20;
  return { valid, reason: observerFinishedEarly ? 'native observer exited before the measured cohorts completed' : valid ? 'full live roster verified independently by every shard' : 'incomplete or interrupted cohort',
    sdkPeersJoined: joined, roomId: reports[0].roomId, sharedFullSecondsLowerBound: Number(sharedFullSecondsLowerBound.toFixed(2)),
    maxHelperCpuPercent, maxHelperLoopExcessP95Ms, helperSaturationSuspected,
    capacityEvidenceQualified: valid && sharedFullSecondsLowerBound >= 60 && !helperSaturationSuspected };
}

async function main(argv) {
  const options = { shards: 3, seconds: 75, output: '', native: '', cache: '' };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i], value = argv[++i];
    if (key === '--shards') options.shards = Number(value);
    else if (key === '--seconds') options.seconds = Number(value);
    else if (key === '--output-dir') options.output = value;
    else if (key === '--native-executable') options.native = value;
    else if (key === '--admission-cache') options.cache = value;
    else throw Error(`Unknown option ${key}`);
  }
  if (!Number.isInteger(options.shards) || options.shards < 2 || options.shards > 6) throw Error('--shards must be 2..6');
  if (!Number.isInteger(options.seconds) || options.seconds < 65 || options.seconds > 180) throw Error('--seconds must be 65..180');
  if (!options.output || (options.native && !path.isAbsolute(options.native))) throw Error('Require --output-dir and an absolute native executable path if launching an observer');
  const output = path.resolve(options.output);
  await mkdir(output, { recursive: true });
  const temporary = await mkdtemp(path.join(tmpdir(), 'warbase-shards-'));
  const abort = new AbortController();
  const children = [], streams = [], completions = [];
  let observer, observerCompletion, roomId, readyCount = 0, stopping = false, observerFinishedEarly = false;
  const stop = () => { stopping = true; abort.abort(); children.forEach(c => c.kill('SIGTERM')); observer?.kill('SIGTERM'); };
  const onStop = () => stop();
  process.once('SIGTERM', onStop); process.once('SIGINT', onStop);
  const deadline = setTimeout(stop, 600_000);
  let hardStop;
  try {
    console.log(`PREPARING signed admission for 63 peers; endpoint=${ENDPOINT}`);
    const admission = await prepareAdmissionTickets(63, (options.seconds + 240) * 1000, options.cache, abort.signal);
    const sizes = Array.from({ length: options.shards }, (_, i) => Math.floor(63 / options.shards) + Number(i < 63 % options.shards));
    let offset = 0;
    const caches = [];
    for (let i = 0; i < sizes.length; i++) {
      caches.push(path.join(temporary, `tickets-${i}.json`));
      await writeFile(caches[i], JSON.stringify({ endpoint: ENDPOINT, tickets: admission.tickets.slice(offset, offset + sizes[i]) }), { mode: 0o600 });
      offset += sizes[i];
    }
    const launch = (i) => {
      const args = ['--url', ENDPOINT, '--map', 'industrial', '--mode', 'CONQUEST', '--peers', String(sizes[i]),
        '--total-peers', '63', '--seconds', String(options.seconds), '--observer', 'QA_NATIVE_APP', '--observer-timeout', '120',
        '--output', path.join(output, `shard-${i}.json`), '--admission-cache', caches[i], '--steady', '--coordinated'];
      if (i > 0) args.push('--room-id', roomId);
      const child = fork(HARNESS, args, { stdio: ['ignore', 'pipe', 'pipe', 'ipc'] });
      children.push(child);
      const log = createWriteStream(path.join(output, `shard-${i}.log`)); streams.push(log);
      child.stdout.pipe(log); child.stderr.pipe(log, { end: false });
      child.on('message', message => {
        if (message?.type === 'room' && !roomId) {
          roomId = message.roomId; console.log(`PREPARED_ROOM room_id=${roomId}`);
          if (options.native) {
            const nativeLog = createWriteStream(path.join(output, 'native.log')); streams.push(nativeLog);
            observer = spawn(options.native, ['--resolution', '1280x720', '--', 'qa_official', `qa_room=${roomId}`,
              'qa_map=industrial', `qa_seconds=${options.seconds + 45}`, `qa_output=${path.join(output, 'native.json')}`], { stdio: ['ignore', 'pipe', 'pipe'] });
            observer.stdout.pipe(nativeLog); observer.stderr.pipe(nativeLog, { end: false });
            observerCompletion = new Promise(resolve => { observer.once('exit', code => {
              if (!stopping && children.some(c => c.exitCode === null && c.signalCode === null)) { observerFinishedEarly = true; stop(); }
              resolve(code);
            }); observer.once('error', () => { stop(); resolve(1); }); });
          }
          for (let next = 1; next < sizes.length; next++) launch(next);
        }
        if (message?.type === 'ready') {
          readyCount++; console.log(`SHARD_READY ${readyCount}/${sizes.length}`);
          if (readyCount === sizes.length) { const at = Date.now() + 1500; children.forEach(c => c.send({ type: 'start', at })); }
        }
      });
      completions.push(new Promise(resolve => {
        child.once('error', () => { stop(); resolve(1); });
        child.once('exit', code => { if (code !== 0 && !stopping) stop(); resolve(code); });
      }));
    };
    launch(0);
    // More child promises are appended after shard 0 creates the room.
    await completions[0];
    const codes = await Promise.all(completions);
    if (observerCompletion) await observerCompletion;
    const reports = await Promise.all(sizes.map((_, i) => readFile(path.join(output, `shard-${i}.json`), 'utf8').then(JSON.parse)));
    const summary = { ...summarizeShards(reports, { observerFinishedEarly }), shardCount: sizes.length, peerDistribution: sizes, exitCodes: codes,
      observerFinishedEarly, endpoint: ENDPOINT, observer: options.native ? 'packaged-native' : 'external',
      limits: 'Latency percentiles stay per-shard; percentiles are not averaged. Helper qualification is not a client FPS or server tick pass.' };
    await writeFile(path.join(output, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
    console.log(JSON.stringify(summary));
    process.exitCode = summary.capacityEvidenceQualified ? 0 : 1;
  } finally {
    stop();
    hardStop = setTimeout(() => { children.forEach(c => c.kill('SIGKILL')); observer?.kill('SIGKILL'); }, 10_000);
    hardStop.unref();
    clearTimeout(deadline);
    await Promise.allSettled(completions);
    clearTimeout(hardStop);
    for (const stream of streams) stream.end();
    await rm(temporary, { recursive: true, force: true });
    process.off('SIGTERM', onStop); process.off('SIGINT', onStop);
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => { console.error(`MULTIPROCESS_LOAD_FAILED ${error.message}`); process.exitCode = 1; });
}
