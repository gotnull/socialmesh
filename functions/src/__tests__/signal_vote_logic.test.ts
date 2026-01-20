import { computeVoteDeltas, computeReplyDepth } from '../social';

describe('Signal vote aggregation helpers', () => {
  test('computeVoteDeltas handles new upvote', () => {
    const deltas = computeVoteDeltas(undefined, 1);
    expect(deltas).toEqual({ upDelta: 1, downDelta: 0 });
  });

  test('computeVoteDeltas handles new downvote', () => {
    const deltas = computeVoteDeltas(undefined, -1);
    expect(deltas).toEqual({ upDelta: 0, downDelta: 1 });
  });

  test('computeVoteDeltas handles vote removal', () => {
    const deltas = computeVoteDeltas(1, undefined);
    expect(deltas).toEqual({ upDelta: -1, downDelta: 0 });
  });

  test('computeVoteDeltas handles vote switch', () => {
    const deltas = computeVoteDeltas(1, -1);
    expect(deltas).toEqual({ upDelta: -1, downDelta: 1 });
  });

  test('computeVoteDeltas returns null for no-op', () => {
    const deltas = computeVoteDeltas(1, 1);
    expect(deltas).toBeNull();
  });
});

describe('Signal comment depth helper', () => {
  test('computeReplyDepth clamps at max depth', () => {
    expect(computeReplyDepth(0, 8)).toBe(1);
    expect(computeReplyDepth(7, 8)).toBe(8);
    expect(computeReplyDepth(8, 8)).toBe(8);
  });
});
