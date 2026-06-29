import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/epc_remote_data_source.dart';

// ──────────────────────────────────────────────────────────────────────────────
// State
// ──────────────────────────────────────────────────────────────────────────────

sealed class LookupState extends Equatable {
  const LookupState();

  @override
  List<Object?> get props => [];
}

/// Nothing has been scanned or entered yet.
class LookupIdle extends LookupState {
  const LookupIdle();
}

/// A resolve call is in flight.
class LookupResolving extends LookupState {
  final String query;
  const LookupResolving(this.query);

  @override
  List<Object?> get props => [query];
}

/// Resolve succeeded — may be a match or an unregistered tag.
class LookupResolved extends LookupState {
  final ScanMatch match;
  final String query;
  const LookupResolved({required this.match, required this.query});

  @override
  List<Object?> get props => [match, query];
}

/// Resolve failed.
class LookupError extends LookupState {
  final String message;
  final String query;
  final bool isOffline;
  const LookupError({
    required this.message,
    required this.query,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [message, query, isOffline];
}

// ──────────────────────────────────────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────────────────────────────────────

class LookupNotifier extends StateNotifier<LookupState> {
  final EpcRemoteDataSource _dataSource;

  LookupNotifier(this._dataSource) : super(const LookupIdle());

  /// Resolve an EPC, barcode, or item code against the backend.
  Future<void> resolve(String input) async {
    final query = input.trim();
    if (query.isEmpty) return;
    state = LookupResolving(query);
    try {
      final match = await _dataSource.resolve(query);
      state = LookupResolved(match: match, query: query);
    } on NetworkException catch (e) {
      state = LookupError(
        message: e.message,
        query: query,
        isOffline: true,
      );
    } on AuthException catch (e) {
      state = LookupError(message: e.message, query: query);
    } on ServerException catch (e) {
      state = LookupError(message: e.message, query: query);
    } catch (e) {
      state = LookupError(
        message: e.toString(),
        query: query,
      );
    }
  }

  /// Bind an EPC to a DocType record, then re-resolve.
  Future<void> bind(String epc, String doctype, String name) async {
    final trimmedName = name.trim();
    if (epc.isEmpty || trimmedName.isEmpty) return;
    state = LookupResolving(epc);
    try {
      await _dataSource.bind(doctype, trimmedName, epc);
      final match = await _dataSource.resolve(epc);
      state = LookupResolved(match: match, query: epc);
    } on NetworkException catch (e) {
      state = LookupError(
        message: e.message,
        query: epc,
        isOffline: true,
      );
    } on AuthException catch (e) {
      state = LookupError(message: e.message, query: epc);
    } on ServerException catch (e) {
      state = LookupError(message: e.message, query: epc);
    } catch (e) {
      state = LookupError(message: e.toString(), query: epc);
    }
  }

  /// Reset to idle.
  void clear() => state = const LookupIdle();
}
