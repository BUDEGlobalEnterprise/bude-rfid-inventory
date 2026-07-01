import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/attendance_queue.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
    ref.watch(attendanceQueueProvider),
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
    state = state.copyWith(isLoading: true);
    try {
      state = state.copyWith(
        isLoading: false,
        status: await _repository.status(),
        pendingCount: (await _repository.pending()).length,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        pendingCount: (await _repository.pending()).length,
      );
    }
  }

  Future<void> check(String type) async {
    await _repository.check(type);
    await load();
  }
}

class AttendanceState {
  const AttendanceState({
    this.isLoading = false,
    this.status,
    this.pendingCount = 0,
  });

  final bool isLoading;
  final AttendanceStatus? status;
  final int pendingCount;

  AttendanceState copyWith({
    bool? isLoading,
    AttendanceStatus? status,
    int? pendingCount,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}
