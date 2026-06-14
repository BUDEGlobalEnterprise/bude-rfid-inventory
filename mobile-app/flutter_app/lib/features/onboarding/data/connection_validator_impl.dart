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

    // Step 1: frappe.ping — genuinely allow_guest. Confirms the host is a
    // reachable Frappe server without hitting the guest-blocked version endpoint.
    final frappeResult = await _probeFrappe(dio);
    if (frappeResult != _FrappeOk.instance) {
      return switch (frappeResult) {
        _FrappeUnreachable(:final reason) => ConnectionUnreachable(reason),
        _FrappeNotErpNext(:final reason) => ConnectionNotErpNext(reason),
        _ => const ConnectionUnknown('Unexpected Frappe probe result.'),
      };
    }

    // Step 2: bude_api health ping — provides budeApiVersion and erpnextVersion
    // (resolved server-side so guests can receive it).
    final pingResult = await _probePing(dio);
    return switch (pingResult) {
      _PingOk(:final budeApiVersion, :final erpnextVersion) => ConnectionOk(
          erpnextVersion: erpnextVersion ?? 'unknown',
          budeApiVersion: budeApiVersion,
        ),
      _PingMissing() => const ConnectionBudeApiMissing(
          'ERPNext reachable, but bude_api is not installed on this site.',
        ),
      _PingUnknown(:final reason) => ConnectionUnknown(reason),
    };
  }

  Future<_FrappeResult> _probeFrappe(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/frappe.ping',
      );
      final message = response.data?['message'];
      if (message != 'pong') {
        return const _FrappeNotErpNext('Server responded but is not Frappe.');
      }
      return _FrappeOk.instance;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return const _FrappeNotErpNext(
          'Server reachable but Frappe API not found.',
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return _FrappeUnreachable(e.message ?? 'Connection failed.');
      }
      if (status != null && status >= 500) {
        return _FrappeUnknown('Server error ($status).');
      }
      return _FrappeUnknown(e.message ?? 'Unknown error.');
    } catch (e) {
      return _FrappeUnknown(e.toString());
    }
  }

  Future<_PingResult> _probePing(Dio dio) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/method/bude_api.api.health.ping',
      );
      final body = response.data;
      // health.ping returns its dict directly; Frappe wraps it in {"message": ...}.
      final message = body?['message'];
      if (message is! Map) {
        return const _PingUnknown('Unexpected ping response shape.');
      }
      final version = message['version'] as String?;
      if (version == null) {
        return const _PingUnknown('bude_api responded without a version.');
      }
      final erpnextVersion = message['erpnext_version'] as String?;
      return _PingOk(budeApiVersion: version, erpnextVersion: erpnextVersion);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 404 || status == 500) {
        return const _PingMissing();
      }
      return _PingUnknown(e.message ?? 'Network error during capability probe.');
    } catch (e) {
      return _PingUnknown(e.toString());
    }
  }
}

// --- internal result helpers ---

sealed class _FrappeResult {
  const _FrappeResult();
}

class _FrappeOk extends _FrappeResult {
  const _FrappeOk._();
  static const instance = _FrappeOk._();
}

class _FrappeUnreachable extends _FrappeResult {
  final String reason;
  const _FrappeUnreachable(this.reason);
}

class _FrappeNotErpNext extends _FrappeResult {
  final String reason;
  const _FrappeNotErpNext(this.reason);
}

class _FrappeUnknown extends _FrappeResult {
  final String reason;
  const _FrappeUnknown(this.reason);
}

sealed class _PingResult {
  const _PingResult();
}

class _PingOk extends _PingResult {
  final String budeApiVersion;
  final String? erpnextVersion;
  const _PingOk({required this.budeApiVersion, this.erpnextVersion});
}

class _PingMissing extends _PingResult {
  const _PingMissing();
}

class _PingUnknown extends _PingResult {
  final String reason;
  const _PingUnknown(this.reason);
}
