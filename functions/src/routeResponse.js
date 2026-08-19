// searchRoute Callable Functionのレスポンス整形（クライアントの色分け表示用に区間ごとの
// 距離・安心スコアを付与する）。純粋なデータ変換のみを切り出し、unit testしやすくしている。

export function buildSegmentBreakdown(graph, path) {
  const segments = [];
  for (let i = 0; i < path.length - 1; i++) {
    const fromId = path[i];
    const toId = path[i + 1];
    const edge = (graph.adjacency.get(fromId) ?? []).find((e) => e.to === toId);
    if (!edge) continue;
    const from = graph.nodeById.get(fromId);
    const to = graph.nodeById.get(toId);
    const fullEdge = graph.edgeById.get(edge.edgeId);
    segments.push({
      edgeId: edge.edgeId,
      fromLat: from.lat,
      fromLon: from.lon,
      toLat: to.lat,
      toLon: to.lon,
      distanceM: edge.distanceM,
      comfortScore: fullEdge?.shadowScore ?? 0,
    });
  }
  return segments;
}
