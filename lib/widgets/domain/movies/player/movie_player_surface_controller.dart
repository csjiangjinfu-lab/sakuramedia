import 'dart:async';

import 'package:flutter/foundation.dart';

class MoviePlayerSurfaceController {
  final StreamController<Duration> _seekController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _playController =
      StreamController<void>.broadcast();
  final StreamController<void> _pauseController =
      StreamController<void>.broadcast();

  Stream<Duration> get seekStream => _seekController.stream;
  Stream<void> get playStream => _playController.stream;
  Stream<void> get pauseStream => _pauseController.stream;

  void seekTo(Duration position) {
    if (_seekController.isClosed) {
      return;
    }
    debugPrint(
      '[player-debug] surface_controller_seek_to seconds=${position.inSeconds}',
    );
    _seekController.add(position);
  }

  void play() {
    if (_playController.isClosed) {
      return;
    }
    debugPrint('[player-debug] surface_controller_play');
    _playController.add(null);
  }

  /// 请求暂停底层播放器。创建切片前调用，释放远端拉流连接，
  /// 避免播放流与切片流并发命中同一 115 直链而触发 403。
  void pause() {
    if (_pauseController.isClosed) {
      return;
    }
    debugPrint('[player-debug] surface_controller_pause');
    _pauseController.add(null);
  }

  void dispose() {
    _seekController.close();
    _playController.close();
    _pauseController.close();
  }
}
