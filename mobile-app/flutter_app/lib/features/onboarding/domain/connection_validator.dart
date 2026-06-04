import 'connection_check_result.dart';

abstract class ConnectionValidator {
  /// Probes [baseUrl] (no trailing slash) and reports whether it's a usable
  /// ERPNext server with `bude_api` installed.
  Future<ConnectionCheckResult> check(String baseUrl);
}
