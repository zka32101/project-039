// prototype/src/routeSearch.js と同一。
// 重み付き最短経路探索（Dijkstra）。
// コスト = 距離 × (1 - shadeWeight × shadowScore) — 影が濃い区間ほどコストが下がり優先されやすくなる。
import MinHeap from './minHeap.js';

/**
 * @param {ReturnType<import('./buildGraph.js').buildGraph>} graph
 * @param {Map<string, number>} shadowScores edgeId -> 0..1
 * @param {string} originNodeId
 * @param {string} destNodeId
 * @param {{shadeWeight?: number}} [weightPrefs]
 * @returns {{path: string[], distanceM: number, cost: number} | null}
 */
export function searchRoute(graph, shadowScores, originNodeId, destNodeId, weightPrefs = {}) {
  const shadeWeight = weightPrefs.shadeWeight ?? 0.5; // 0=距離最優先, 1=安心スコア最優先

  if (!graph.nodeById.has(originNodeId) || !graph.nodeById.has(destNodeId)) return null;

  const edgeById = graph.edgeById ?? new Map(graph.edges.map((e) => [e.id, e]));

  const dist = new Map([[originNodeId, 0]]);
  const prevEdge = new Map();
  const prevNode = new Map();
  const visited = new Set();
  const heap = new MinHeap();
  heap.push(originNodeId, 0);

  while (!heap.isEmpty()) {
    const { item: current, priority: currentCost } = heap.pop();
    if (visited.has(current)) continue;
    visited.add(current);
    if (current === destNodeId) break;

    const neighbors = graph.adjacency.get(current) ?? [];
    for (const { to, edgeId, distanceM } of neighbors) {
      if (visited.has(to)) continue;
      const shadowScore = shadowScores.get(edgeId) ?? 0;
      const edgeCost = distanceM * (1 - shadeWeight * shadowScore);
      const newCost = currentCost + edgeCost;
      if (newCost < (dist.get(to) ?? Infinity)) {
        dist.set(to, newCost);
        prevEdge.set(to, edgeId);
        prevNode.set(to, current);
        heap.push(to, newCost);
      }
    }
  }

  if (!dist.has(destNodeId)) return null;

  // 経路復元
  const path = [destNodeId];
  let cur = destNodeId;
  let distanceM = 0;
  while (cur !== originNodeId) {
    const edgeId = prevEdge.get(cur);
    const prev = prevNode.get(cur);
    if (!edgeId || !prev) break;
    const edge = edgeById.get(edgeId);
    distanceM += edge?.distanceM ?? 0;
    path.push(prev);
    cur = prev;
  }
  path.reverse();

  return { path, distanceM, cost: dist.get(destNodeId) };
}
