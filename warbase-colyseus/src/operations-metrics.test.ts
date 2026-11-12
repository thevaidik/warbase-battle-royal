import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import type { Request, Response } from 'express';
import express from 'express';
import { createOperationsMetricsHandler } from './metrics-handler.js';
import { incrementProcessOperation, processOperationsMetrics, processTimingSnapshot, recordProcessTick } from './operations-metrics.js';

function invoke(token: string, authorization: string, snapshot: () => unknown) {
  let status = 200;
  let body: unknown;
  const headers: Record<string, string> = {};
  const req = { get: () => authorization, socket: { remoteAddress: '127.0.0.1' } } as unknown as Request;
  const res = {
    setHeader: (name: string, value: string) => { headers[name] = value; },
    sendStatus: (value: number) => { status = value; return res; },
    json: (value: unknown) => { body = value; return res; },
  } as unknown as Response;
  createOperationsMetricsHandler(token, snapshot)(req, res);
  return { status, body, headers };
}

test('operations metrics handler disables, denies, and serves authorized requests', () => {
  let calls = 0;
  const snapshot = () => { calls++; return { process: true }; };
  assert.equal(invoke('', 'Bearer secret', snapshot).status, 404);
  assert.equal(invoke('secret', '', snapshot).status, 401);
  assert.equal(invoke('secret', 'Bearer wrong', snapshot).status, 401);
  const remoteReq = { get: () => 'Bearer secret', socket: { remoteAddress: '10.0.0.7' } } as unknown as Request;
  const remoteRes = { sendStatus: (status: number) => status } as unknown as Response;
  assert.equal(createOperationsMetricsHandler('secret', snapshot)(remoteReq, remoteRes), 403);
  const ok = invoke('secret', 'Bearer secret', snapshot);
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body, { process: true });
  assert.equal(ok.headers['Cache-Control'], 'no-store');
  assert.equal(calls, 1);
});

test('mounted metrics HTTP route enforces disabled, unauthorized and authorized requests', async (t) => {
  const app = express();
  app.get('/internal/metrics', createOperationsMetricsHandler('route-secret', () => ({ sample: 'ok' })));
  const server = createServer(app);
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve());
  });
  t.after(() => new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const endpoint = `http://127.0.0.1:${address.port}/internal/metrics`;
  assert.equal((await fetch(endpoint)).status, 401);
  assert.equal((await fetch(endpoint, { headers: { authorization: 'Bearer wrong' } })).status, 401);
  const authorized = await fetch(endpoint, { headers: { authorization: 'Bearer route-secret' } });
  assert.equal(authorized.status, 200);
  assert.equal(authorized.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await authorized.json(), { sample: 'ok' });

  const disabledApp = express();
  disabledApp.get('/internal/metrics', createOperationsMetricsHandler('', () => ({ sample: 'should-not-leak' })));
  const disabledServer = createServer(disabledApp);
  await new Promise<void>((resolve, reject) => {
    disabledServer.once('error', reject);
    disabledServer.listen(0, '127.0.0.1', () => resolve());
  });
  t.after(() => new Promise<void>((resolve, reject) => disabledServer.close((error) => error ? reject(error) : resolve())));
  const disabledAddress = disabledServer.address();
  assert.ok(disabledAddress && typeof disabledAddress !== 'string');
  assert.equal((await fetch(`http://127.0.0.1:${disabledAddress.port}/internal/metrics`, { headers: { authorization: 'Bearer route-secret' } })).status, 404);
});

test('process metrics retain bounded timing samples and counters independently of rooms', () => {
  const joinedBefore = processOperationsMetrics.joined;
  incrementProcessOperation('joined');
  recordProcessTick(1, 0.1);
  recordProcessTick(3, 0.3);
  assert.equal(processOperationsMetrics.joined, joinedBefore + 1);
  const snapshot = processTimingSnapshot();
  assert.ok(snapshot.recent_window_samples >= 2);
  assert.ok(snapshot.tick_p95_ms >= 1);
  assert.ok(snapshot.tick_p99_ms >= snapshot.tick_p95_ms);
});
