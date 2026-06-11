import 'dart:async';
import 'dart:math' as math;

import '../network/network_info_impl.dart';
import '../utils/logger.dart';
import 'op_submitter.dart';
import 'pending_operation.dart';
import 'sync_queue.dart';

/// Background processor that drains [SyncQueue] when the device is online.
///
/// Triggers:
/// - On `start()` — one immediate drain attempt
/// - When connectivity changes from offline → online
/// - On a periodic timer (default 30s) as a fallback
/// - On explicit `kick()` call (e.g. after the user retries from the UI)
class SyncEngine {
  static const int _maxAttempts = 5;
  static const Duration _pollInterval = Duration(seconds: 30);

  final SyncQueue queue;
  final NetworkInfoImpl networkInfo;
  final Map<String, OpSubmitter> _submitters = {};

  StreamSubscription<bool>? _connectivitySub;
  Timer? _pollTimer;
  bool _draining = false;
  bool _started = false;

  SyncEngine({
    required this.queue,
    required this.networkInfo,
    List<OpSubmitter> submitters = const [],
  }) {
    for (final s in submitters) {
      registerSubmitter(s);
    }
  }

  void registerSubmitter(OpSubmitter submitter) {
    _submitters[submitter.type] = submitter;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _connectivitySub = networkInfo
        .onConnectivityChanged()
        .listen((online) {
      if (online) kick();
    });

    _pollTimer = Timer.periodic(_pollInterval, (_) => kick());

    // Kick once immediately in case ops accumulated while offline.
    unawaited(kick());
  }

  Future<void> stop() async {
    _started = false;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Explicitly request a drain attempt.
  Future<void> kick() async {
    if (_draining) return;
    if (!await networkInfo.isConnected) return;

    _draining = true;
    try {
      await _drain();
    } finally {
      _draining = false;
    }
  }

  Future<void> _drain() async {
    while (true) {
      final op = queue.nextEligible();
      if (op == null) break;

      final submitter = _submitters[op.type];
      if (submitter == null) {
        appLogger.w('No submitter registered for op type "${op.type}".');
        await queue.update(
          op.copyWith(
            status: OpStatus.failed,
            lastError: 'Unsupported op type "${op.type}"',
          ),
        );
        continue;
      }

      await queue.update(
        op.copyWith(
          status: OpStatus.inflight,
          clearError: true,
        ),
      );

      final result = await _safeSubmit(submitter, op);
      await _applyResult(op, result);
    }
  }

  Future<SubmitResult> _safeSubmit(
    OpSubmitter submitter,
    PendingOperation op,
  ) async {
    try {
      return await submitter.submit(op);
    } catch (e, st) {
      appLogger.e('Submitter for ${op.type} threw', error: e, stackTrace: st);
      return SubmitRetryable(e.toString());
    }
  }

  Future<void> _applyResult(PendingOperation op, SubmitResult result) async {
    switch (result) {
      case SubmitSuccess(:final serverRef):
        await queue.update(
          op.copyWith(
            status: OpStatus.succeeded,
            serverRef: serverRef,
            clearError: true,
            clearNextRetry: true,
          ),
        );

      case SubmitFatal(:final error):
        await queue.update(
          op.copyWith(
            status: OpStatus.failed,
            lastError: error,
            clearNextRetry: true,
          ),
        );

      case SubmitRetryable(:final error):
        final nextAttempts = op.attempts + 1;
        if (nextAttempts >= _maxAttempts) {
          await queue.update(
            op.copyWith(
              status: OpStatus.failed,
              attempts: nextAttempts,
              lastError: 'After $_maxAttempts attempts: $error',
              clearNextRetry: true,
            ),
          );
        } else {
          final backoffSec = math.min(300, math.pow(2, nextAttempts).toInt());
          await queue.update(
            op.copyWith(
              status: OpStatus.pending,
              attempts: nextAttempts,
              lastError: error,
              nextRetryAt: DateTime.now()
                  .toUtc()
                  .add(Duration(seconds: backoffSec)),
            ),
          );
        }
    }
  }
}
