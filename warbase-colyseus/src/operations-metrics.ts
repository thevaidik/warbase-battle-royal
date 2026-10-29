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

export function newRoomOperationsMetrics(): RoomOperationsMetrics {
  return { tickCount: 0, tickOverruns: 0, lateTicks: 0, lastTickDurationMs: 0, maxTickDurationMs: 0, totalTickDurationMs: 0,
    consumedInputs: 0, emptyInputSteps: 0, joined: 0, left: 0, rejectedAdmissions: 0, rejectedPayloads: 0, rejectedMessages: 0, rateLimitedMessages: 0 };
}
