import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';

/// 播放期间每 15s 上报一次「这个媒体正在播」。
///
/// 后端心跳 TTL 45s，剪辑队列据此跳过同媒体的任务。
///
/// 所有 HTTP 调用都排进同一条 FIFO 链，保证 stop() 的 DELETE 与 start() 的
/// POST 按调用顺序落地：暂停后立刻恢复是「清旧再报新」，停止后的清理也不会
/// 被更早发出的慢 POST 覆盖。
class PlaybackHeartbeatService {
  PlaybackHeartbeatService(this._api);

  final ClipsApi _api;
  final String clientId = _generateClientId();
  static const Duration interval = Duration(seconds: 15);

  int? _mediaId;
  Timer? _timer;

  /// 串行化心跳请求的 FIFO 链；每一步的错误都在链内吞掉，避免链断掉。
  Future<void> _chain = Future.value();

  static String _generateClientId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  void _enqueue(Future<void> Function() action) {
    _chain = _chain.then((_) => action()).catchError((_) {});
  }

  void start(int mediaId) {
    if (_mediaId == mediaId && _timer != null) {
      return;
    }
    final previous = _mediaId;
    _timer?.cancel();
    _timer = null;
    _mediaId = mediaId;
    _enqueue(() async {
      if (previous != null) {
        await _clear(previous);
      }
      await _sendOnce(mediaId);
    });
    _timer = Timer.periodic(interval, (_) {
      final id = _mediaId;
      if (id != null) {
        _enqueue(() => _sendOnce(id));
      }
    });
  }

  void stop() {
    final mediaId = _mediaId;
    _timer?.cancel();
    _timer = null;
    _mediaId = null;
    if (mediaId != null) {
      _enqueue(() => _clear(mediaId));
    }
  }

  /// Provider 销毁时调用：只清本地状态，不再发网络请求。
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _mediaId = null;
  }

  Future<void> _sendOnce(int mediaId) async {
    try {
      await _api.touchPlaybackHeartbeat(mediaId: mediaId, clientId: clientId);
    } catch (_) {
      // 心跳失败不影响播放，等下一次定时器重试。
    }
  }

  Future<void> _clear(int mediaId) async {
    try {
      await _api.clearPlaybackHeartbeat(mediaId: mediaId, clientId: clientId);
    } catch (_) {
      // 清除失败时后端最多保留 45s，可接受。
    }
  }
}

final playbackHeartbeatServiceProvider = Provider<PlaybackHeartbeatService>((
  ref,
) {
  final service = PlaybackHeartbeatService(ref.watch(clipsApiProvider));
  ref.onDispose(service.dispose);
  return service;
});
