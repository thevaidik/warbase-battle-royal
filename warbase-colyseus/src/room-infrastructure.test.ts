import test from 'node:test';
import assert from 'node:assert/strict';
import { createRoomInfrastructure, roomInfrastructureConfig } from './room-infrastructure.js';

test('single process stays dependency-free at runtime unless Redis is configured', async () => {
  assert.equal(roomInfrastructureConfig({}), null);
  assert.deepEqual(await createRoomInfrastructure({}), {});
});

test('Redis worker settings require explicit routes and validated connection settings', () => {
  assert.throws(() => roomInfrastructureConfig({ REDIS_URL: 'http://localhost' }), /redis/);
  assert.throws(() => roomInfrastructureConfig({ REDIS_URL: 'redis://localhost' }), /PUBLIC_ADDRESS/);
  assert.throws(() => roomInfrastructureConfig({ REDIS_URL: 'redis://localhost/99', PUBLIC_ADDRESS: 'localhost:8081' }), /database/);
  const config = roomInfrastructureConfig({ REDIS_URL: 'rediss://game:secret@localhost:6380/2', PUBLIC_ADDRESS: 'worker.example/game' });
  assert.equal(config?.host, 'localhost'); assert.equal(config?.port, 6380);
  assert.equal(config?.username, 'game'); assert.equal(config?.password, 'secret');
  assert.equal(config?.db, 2); assert.deepEqual(config?.tls, {});
});
