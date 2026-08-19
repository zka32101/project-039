// 道路網（Overpass由来の nodes/roads）から、経路探索用の重み無し隣接グラフを構築する。
import { haversineDistanceM } from './geo.js';

/**
 * @param {{nodes: Array<{id:string,lat:number,lon:number}>, roads: Array<{id:string,nodeIds:string[],name?:string}>}} data
 * @returns {{
 *   nodeById: Map<string,{id:string,lat:number,lon:number}>,
 *   adjacency: Map<string, Array<{to:string, edgeId:string, distanceM:number}>>,
 *   edges: Array<{id:string, roadId:string, from:string, to:string, distanceM:number}>
 * }}
 */
export function buildGraph({ nodes, roads }) {
  const nodeById = new Map(nodes.map((n) => [n.id, n]));
  const adjacency = new Map(nodes.map((n) => [n.id, []]));
  const edges = [];

  for (const road of roads) {
    for (let i = 0; i < road.nodeIds.length - 1; i++) {
      const fromId = road.nodeIds[i];
      const toId = road.nodeIds[i + 1];
      const from = nodeById.get(fromId);
      const to = nodeById.get(toId);
      if (!from || !to) continue; // 欠損ノード（データ不整合）はスキップ

      const distanceM = haversineDistanceM([from.lat, from.lon], [to.lat, to.lon]);
      const edgeId = `${road.id}_${i}`;
      edges.push({ id: edgeId, roadId: road.id, from: fromId, to: toId, distanceM });

      // 歩道として双方向通行を仮定
      adjacency.get(fromId).push({ to: toId, edgeId, distanceM });
      adjacency.get(toId).push({ to: fromId, edgeId, distanceM });
    }
  }

  return { nodeById, adjacency, edges, edgeById: new Map(edges.map((e) => [e.id, e])) };
}
