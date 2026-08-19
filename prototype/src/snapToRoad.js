// 投稿UIで指がなぞった軌跡を、最寄りの道路区間（グラフエッジ）にスナップするロジック。
// 設計書 Step5.5「投稿演出」／Code引き継ぎ書「投稿位置はスナップ後のroadSegmentIdのみ保存」に対応。
// クライアント（Flutter）側でも同等のロジックをDartに移植する前提で、まずここで検証する。
import { pointToSegmentDistanceM } from './geo.js';

/**
 * 軌跡（緯度経度の配列）を、最も近い道路区間(edge)へスナップする。
 * @param {Array<[number, number]>} trace ユーザーがなぞった軌跡点列
 * @param {ReturnType<import('./buildGraph.js').buildGraph>} graph
 * @param {number} [maxSnapDistanceM] これを超えて離れている場合はスナップ対象外とする閾値
 * @returns {{ edgeId: string, roadId: string, avgDistanceM: number } | null}
 */
export function snapTraceToRoad(trace, graph, maxSnapDistanceM = 30) {
  if (trace.length === 0) return null;

  const edgeVotes = new Map(); // edgeId -> {totalDistance, count}

  for (const point of trace) {
    let best = null;
    for (const edge of graph.edges) {
      const from = graph.nodeById.get(edge.from);
      const to = graph.nodeById.get(edge.to);
      if (!from || !to) continue;
      const d = pointToSegmentDistanceM(point, [from.lat, from.lon], [to.lat, to.lon]);
      if (d > maxSnapDistanceM) continue;
      if (!best || d < best.distance) best = { edgeId: edge.id, distance: d };
    }
    if (best) {
      const v = edgeVotes.get(best.edgeId) ?? { totalDistance: 0, count: 0 };
      v.totalDistance += best.distance;
      v.count += 1;
      edgeVotes.set(best.edgeId, v);
    }
  }

  if (edgeVotes.size === 0) return null;

  // 軌跡点の大部分（最多得票）がスナップした区間を採用
  let winnerEdgeId = null;
  let winnerVotes = null;
  for (const [edgeId, v] of edgeVotes) {
    if (!winnerVotes || v.count > winnerVotes.count) {
      winnerEdgeId = edgeId;
      winnerVotes = v;
    }
  }

  const edge = graph.edgeById?.get(winnerEdgeId) ?? graph.edges.find((e) => e.id === winnerEdgeId);
  return {
    edgeId: winnerEdgeId,
    roadId: edge?.roadId,
    avgDistanceM: winnerVotes.totalDistance / winnerVotes.count,
  };
}
