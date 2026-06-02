import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  final String username;
  final String token;
  final String? fullName;

  const AuthSession({
    required this.username,
    required this.token,
    this.fullName,
  });

  @override
  List<Object?> get props => [username, token, fullName];
}
