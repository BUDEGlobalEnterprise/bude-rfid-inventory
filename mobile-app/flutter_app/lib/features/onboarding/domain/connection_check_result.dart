import 'package:equatable/equatable.dart';

/// Result of validating a candidate ERPNext server before login.
sealed class ConnectionCheckResult extends Equatable {
  const ConnectionCheckResult();

  @override
  List<Object?> get props => [];
}

class ConnectionOk extends ConnectionCheckResult {
  final String erpnextVersion;
  final String budeApiVersion;

  const ConnectionOk({
    required this.erpnextVersion,
    required this.budeApiVersion,
  });

  @override
  List<Object?> get props => [erpnextVersion, budeApiVersion];
}

/// The host is not reachable at all (DNS / TCP / TLS failure, timeout).
class ConnectionUnreachable extends ConnectionCheckResult {
  final String reason;
  const ConnectionUnreachable(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// The host responded but isn't a Frappe/ERPNext server (or ERPNext isn't installed).
class ConnectionNotErpNext extends ConnectionCheckResult {
  final String reason;
  const ConnectionNotErpNext(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// ERPNext is present but the `bude_api` app isn't installed on the target site.
class ConnectionBudeApiMissing extends ConnectionCheckResult {
  final String reason;
  const ConnectionBudeApiMissing(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// Catch-all for anything else (unexpected HTTP code, malformed body, etc.).
class ConnectionUnknown extends ConnectionCheckResult {
  final String reason;
  const ConnectionUnknown(this.reason);

  @override
  List<Object?> get props => [reason];
}
