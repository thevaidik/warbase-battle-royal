export type RoomOperationsMetrics = {
  tickCount: number;
  tickOverruns: number;
  lateTicks: number;
  lastTickDurationMs: number;
  maxTickDurationMs: number;
  totalTickDurationMs: number;
  consumedInputs: number;
  emptyInputSteps: number;
  joined: number;
  left: number;
  rejectedAdmissions: number;
  rejectedPayloads: number;
  rejectedMessages: number;
  rateLimitedMessages: number;
};

export const roomOperationsMetrics = new Map<string, RoomOperationsMetrics>();
export const serviceOperationsMetrics = {
  roomCreateRejected: 0,
  roomCreateRateLimited: 0,
};

// Process totals survive room disposal. The bounded timing window stores only
// numeric samples, never room or player identifiers.
const PROCESS_SAMPLE_LIMIT = 2048;
const processTickSamples = new Float64Array(PROCESS_SAMPLE_LIMIT);
const processDelaySamples = new Float64Array(PROCESS_SAMPLE_LIMIT);
let processSampleCount = 0;
let processSampleCursor = 0;
let processTickCount = 0;
export const processOperationsMetrics = {
  joined: 0, left: 0, rejectedAdmissions: 0, rejectedPayloads: 0,
  rejectedMessages: 0, rateLimitedMessages: 0,
};

export function incrementProcessOperation(field: keyof typeof processOperationsMetrics): void {
  processOperationsMetrics[field]++;
}

export function recordProcessTick(durationMs: number, schedulingGapMs: number): void {
  processTickCount++;
  processTickSamples[processSampleCursor] = Math.max(0, durationMs);
  processDelaySamples[processSampleCursor] = Math.max(0, schedulingGapMs);
  processSampleCursor = (processSampleCursor + 1) % PROCESS_SAMPLE_LIMIT;
  processSampleCount = Math.min(processSampleCount + 1, PROCESS_SAMPLE_LIMIT);
}

function percentile(samples: number[], p: number): number {
  if (samples.length === 0) return 0;
  const ordered = Array.from(samples).sort((a, b) => a - b);
  return ordered[Math.ceil((ordered.length - 1) * p)];
}

export function processTimingSnapshot() {
  const ticks = Array.from(processTickSamples.slice(0, processSampleCount));
  const delays = Array.from(processDelaySamples.slice(0, processSampleCount));
  return {
    ticks_total: processTickCount,
    recent_window_samples: processSampleCount,
    recent_window_capacity: PROCESS_SAMPLE_LIMIT,
    tick_p50_ms: percentile(ticks, 0.50),
    tick_p95_ms: percentile(ticks, 0.95),
    tick_p99_ms: percentile(ticks, 0.99),
    tick_max_ms: ticks.length ? Math.max(...ticks) : 0,
    scheduling_gap_p95_ms: percentile(delays, 0.95),
    scheduling_gap_max_ms: delays.length ? Math.max(...delays) : 0,
  };
}

export function newRoomOperationsMetrics(): RoomOperationsMetrics {
  return { tickCount: 0, tickOverruns: 0, lateTicks: 0, lastTickDurationMs: 0, maxTickDurationMs: 0, totalTickDurationMs: 0,
    consumedInputs: 0, emptyInputSteps: 0, joined: 0, left: 0, rejectedAdmissions: 0, rejectedPayloads: 0, rejectedMessages: 0, rateLimitedMessages: 0 };
}
