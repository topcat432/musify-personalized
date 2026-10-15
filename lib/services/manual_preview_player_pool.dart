import 'dart:async';

import 'package:musify/services/review_sprint_audio_player.dart';

/// Owns at most one live preview backend and one retirement awaiting confirmation.
/// A timeout never makes a backend available for reuse.
class ManualPreviewPlayerPool {
  ManualPreviewPlayerPool(
    this._createPlayer, {
    this.operationTimeout = const Duration(seconds: 18),
    this.teardownTimeout = const Duration(seconds: 3),
  });

  final ReviewSprintAudioPlayer Function() _createPlayer;
  final Duration operationTimeout;
  final Duration teardownTimeout;
  ManualPreviewPlayerLease? _active;
  Future<bool>? _retirement;
  bool _retirementConfirmed = true;

  ManualPreviewPlayerLease acquire() {
    if (_active != null || !_retirementConfirmed) {
      throw StateError(
        'Preview cleanup is not confirmed. You can still search or save a match.',
      );
    }
    final lease = ManualPreviewPlayerLease._(_createPlayer(), operationTimeout);
    _active = lease;
    return lease;
  }

  Future<void> release(ManualPreviewPlayerLease? lease) async {
    if (lease != null && identical(_active, lease)) {
      _active = null;
      _retirementConfirmed = false;
      final retirement = lease.retire();
      _retirement = retirement;
      unawaited(retirement.then<void>((confirmed) {
        if (identical(_retirement, retirement)) {
          _retirementConfirmed = confirmed;
        }
      }));
    }
    final retirement = _retirement;
    if (retirement != null) {
      await retirement.timeout(teardownTimeout, onTimeout: () => false);
    }
  }
}

class ManualPreviewPlayerLease {
  ManualPreviewPlayerLease._(this.player, this._operationTimeout);

  final ReviewSprintAudioPlayer player;
  final Duration _operationTimeout;
  Future<void> _tail = Future<void>.value();
  Future<bool>? _retirement;
  bool _retired = false;

  bool get retired => _retired;

  Future<void> run(Future<void> Function() action) {
    final next = _tail.then((_) {
      if (_retired) throw StateError('This preview player has been retired.');
      return action();
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next.timeout(_operationTimeout, onTimeout: () {
      unawaited(retire().then<void>((_) {}));
      throw TimeoutException('Preview player did not respond in time.');
    });
  }

  Future<bool> retire() {
    if (_retirement != null) return _retirement!;
    _retired = true;
    // Dispose directly: queuing behind a hung native load would never retire it.
    _retirement = Future<bool>.sync(() async {
      await player.dispose();
      return true;
    }).catchError((Object _) => false);
    return _retirement!;
  }
}
