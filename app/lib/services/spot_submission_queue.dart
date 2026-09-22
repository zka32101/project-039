import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spot_submission.dart';

/// 「オフライン投稿キュー」機能: サーバーへの送信に失敗した投稿（`SpotSubmissionRequest`、
/// スナップ済みの`roadSegmentId`のみを保持しプライバシー設計を保つ）を端末内に保存し、
/// 次回のネットワーク復帰時（`QueueingSpotSubmissionService.flushQueue`呼び出し時）に自動再送する。
/// `RouteResultCache`と同じ、SharedPreferencesベースのJSONリスト永続化パターンを踏襲している。
abstract class SpotSubmissionQueue {
  Future<void> enqueue(SpotSubmissionRequest request);

  /// キューに溜まっている投稿を、保存された順番のまま返す。
  Future<List<SpotSubmissionRequest>> loadAll();

  /// [loadAll]と同じ順番の[index]番目のエントリを削除する（再送成功時に呼ぶ）。
  Future<void> removeAt(int index);
}

class SharedPreferencesSpotSubmissionQueue implements SpotSubmissionQueue {
  static const _key = 'queued_spot_submissions_v1';

  @override
  Future<void> enqueue(SpotSubmissionRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRaw(prefs)..add(request.toJson());
    await prefs.setString(_key, jsonEncode(entries));
  }

  @override
  Future<List<SpotSubmissionRequest>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRaw(prefs).map(SpotSubmissionRequest.fromJson).toList();
  }

  @override
  Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRaw(prefs);
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await prefs.setString(_key, jsonEncode(entries));
  }

  /// 壊れたデータ（フォーマット不正等）はベストエフォートで無視し、空リストとして扱う
  /// （`RouteResultCache._loadRawEntries`と同じ考え方）。
  List<Map<String, dynamic>> _loadRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
