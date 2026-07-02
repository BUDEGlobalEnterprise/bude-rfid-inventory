import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/pending_operations_queue.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
    ref.watch(pendingOperationsQueueProvider),
  );
});

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AttendanceState>((ref) {
  return AttendanceController(ref.watch(attendanceRepositoryProvider))..load();
});

class AttendanceController extends StateNotifier<AttendanceState> {
  AttendanceController(this._repository) : super(const AttendanceState());

  final AttendanceRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final status = await _repository.status();
      final history = await _repository.history();
      state = state.copyWith(
        isLoading: false,
        status: status,
        history: history,
        pendingCount: (await _repository.pending()).length,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        pendingCount: (await _repository.pending()).length,
        error: 'Unable to load attendance.',
      );
    }
  }

  Future<void> check(String type) async {
    state = state.copyWith(isLoading: true, error: null);
    await _repository.check(type);
    await load();
  }

  Future<void> retryPending() async {
    state = state.copyWith(isLoading: true);
    final syncError = await _repository.retryPending();
    await load();
    state = state.copyWith(lastSyncError: syncError);
  }

  Future<void> discardPending() async {
    state = state.copyWith(isLoading: true);
    await _repository.discardPending();
    await load();
  }
}

class AttendanceState {
  const AttendanceState({
    this.isLoading = false,
    this.status,
    this.history = const [],
    this.pendingCount = 0,
    this.error,
    this.lastSyncError,
  });

  final bool isLoading;
  final AttendanceStatus? status;
  final List<AttendanceHistoryRow> history;
  final int pendingCount;
  final String? error;
  final String? lastSyncError;

  AttendanceState copyWith({
    bool? isLoading,
    AttendanceStatus? status,
    List<AttendanceHistoryRow>? history,
    int? pendingCount,
    String? error,
    String? lastSyncError,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      history: history ?? this.history,
      pendingCount: pendingCount ?? this.pendingCount,
      error: error,
      lastSyncError: lastSyncError,
    );
  }
}
