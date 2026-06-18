import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  final String username;
  final String token;
  final String? fullName;
  final List<String> roles;
  final String? defaultWarehouse;

  const AuthSession({
    required this.username,
    required this.token,
    this.fullName,
    this.roles = const [],
    this.defaultWarehouse,
  });

  @override
  List<Object?> get props => [username, token, fullName, roles, defaultWarehouse];
}
