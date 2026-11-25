import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';

/// 播放期间每 15s 上报一次「这个媒体正在播」。
///
/// 后端心跳 TTL 45s，剪辑队列据此跳过同媒体的任务。
class PlaybackHeartbeatService {
  PlaybackHeartbeatService(this._api);

  final ClipsApi _api;
  final String clientId = _generateClientId();
  static const Duration interval = Duration(seconds: 15);

  int? _mediaId;
  Timer? _timer;

  static String _generateClientId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  void start(int mediaId) {
    if (_mediaId == mediaId && _timer != null) {
      return;
    }
    stop();
    _mediaId = mediaId;
    unawaited(_send());
    _timer = Timer.periodic(interval, (_) => unawaited(_send()));
  }

  void stop() {
    final mediaId = _mediaId;
    _timer?.cancel();
    _timer = null;
    _mediaId = null;
    if (mediaId != null) {
      unawaited(_clear(mediaId));
    }
  }

  Future<void> _send() async {
    final mediaId = _mediaId;
    if (mediaId == null) {
      return;
    }
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

final playbackHeartbeatServiceProvider = Provider<PlaybackHeartbeatService>(
  (ref) => PlaybackHeartbeatService(ref.watch(clipsApiProvider)),
);
