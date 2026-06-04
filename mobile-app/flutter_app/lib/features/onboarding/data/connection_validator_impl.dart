import 'package:dio/dio.dart';

import '../domain/connection_check_result.dart';
import '../domain/connection_validator.dart';

class ConnectionValidatorImpl implements ConnectionValidator {
  /// Factory hook for tests — produces a Dio bound to [baseUrl] with short
  /// timeouts. In production we want a fresh Dio per check so the validator
  /// never leaks state into the shared `ApiClient`.
  final Dio Function(String baseUrl) dioFactory;

  ConnectionValidatorImpl({Dio Function(String baseUrl)? dioFactory})
      : dioFactory = dioFactory ?? _defaultDio;

  static Dio _defaultDio(String baseUrl) => Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ),
      );

  @override
  Future<ConnectionCheckResult> check(String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      return const ConnectionUnreachable('URL is empty.');
    }
    final cleaned = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;

    final dio = dioFactory(cleaned);

    // Step 1: Frappe version probe.
    final versionsResult = await _probeVersions(dio);
    if (versionsResult is! _VersionsOk) {
      return versionsResult.toResult();
    }
    final erpnextVersion = versionsResult.erpnextVersion;
    if (erpnextVersion == null) {
      return const ConnectionNotErpNext(
        'Server responded but ERPNext is not installed.',
      );
    }

    // Step 2: bude_api capability probe.
    final pingResult = await _probePing(dio);
    return switch (pingResult) {
      _PingOk(:final budeApiVersion) => ConnectionOk(
          erpnextVersion: erpnextVersion,
          budeApiVersion: budeApiVersion,
        ),
      _PingMissing() => const ConnectionBudeApiMissing(
          'ERPNext reachable, but bude_api is not installed on this site.',
        ),
      _PingUnknown(:final reason) => ConnectionUnknown(reason),
    };
  }

  Future<_VersionsResult> _probeVersions(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/frappe.utils.change_log.get_versions',
      );
      final body = response.data;
      if (body == null) {
        return const _VersionsUnknown('Empty response from version probe.');
      }
      // Frappe wraps method results in {"message": {...}}.
      final message = body['message'];
      if (message is! Map) {
        return const _VersionsNotErpNext('Unexpected version response shape.');
      }
      final erpnext = message['erpnext'];
      final version = erpnext is Map ? erpnext['version'] as String? : null;
      return _VersionsOk(version);
    } on DioException catch (e) {
      return _mapDioToVersions(e);
    } catch (e) {
      return _VersionsUnknown(e.toString());
    }
  }

  Future<_PingResult> _probePing(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.health.ping',
      );
      final body = response.data;
      // health.ping returns its dict directly, Frappe wraps in {"message": ...}.
      final message = body?['message'];
      if (message is! Map) {
        return const _PingUnknown('Unexpected ping response shape.');
      }
      final version = message['version'] as String?;
      if (version == null) {
        return const _PingUnknown('bude_api responded without a version.');
      }
      return _PingOk(version);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 500) {
        return const _PingMissing();
      }
      return _PingUnknown(e.message ?? 'Network error during capability probe.');
    } catch (e) {
      return _PingUnknown(e.toString());
    }
  }

  _VersionsResult _mapDioToVersions(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) {
      // Frappe-style 404 means the method isn't there → likely not Frappe.
      return const _VersionsNotErpNext(
        'Server reachable but Frappe API not found.',
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return _VersionsUnreachable(e.message ?? 'Connection failed.');
    }
    if (status != null && status >= 500) {
      return _VersionsUnknown('Server error ($status).');
    }
    return _VersionsUnknown(e.message ?? 'Unknown error.');
  }
}

// --- internal result helpers ---

sealed class _VersionsResult {
  const _VersionsResult();
  ConnectionCheckResult toResult() => switch (this) {
        _VersionsOk() => throw StateError('toResult on OK is unused'),
        _VersionsUnreachable(:final reason) =>
          ConnectionUnreachable(reason),
        _VersionsNotErpNext(:final reason) => ConnectionNotErpNext(reason),
        _VersionsUnknown(:final reason) => ConnectionUnknown(reason),
      };
}

class _VersionsOk extends _VersionsResult {
  final String? erpnextVersion;
  const _VersionsOk(this.erpnextVersion);
}

class _VersionsUnreachable extends _VersionsResult {
  final String reason;
  const _VersionsUnreachable(this.reason);
}

class _VersionsNotErpNext extends _VersionsResult {
  final String reason;
  const _VersionsNotErpNext(this.reason);
}

class _VersionsUnknown extends _VersionsResult {
  final String reason;
  const _VersionsUnknown(this.reason);
}

sealed class _PingResult {
  const _PingResult();
}

class _PingOk extends _PingResult {
  final String budeApiVersion;
  const _PingOk(this.budeApiVersion);
}

class _PingMissing extends _PingResult {
  const _PingMissing();
}

class _PingUnknown extends _PingResult {
  final String reason;
  const _PingUnknown(this.reason);
}
