import '../../domain/auth_session.dart';

class AuthSessionModel {
  final String user;
  final String? fullName;
  final String apiKey;
  final String apiSecret;

  const AuthSessionModel({
    required this.user,
    required this.apiKey,
    required this.apiSecret,
    this.fullName,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      user: json['user'] as String,
      fullName: json['full_name'] as String?,
      apiKey: json['api_key'] as String,
      apiSecret: json['api_secret'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user,
        'full_name': fullName,
        'api_key': apiKey,
        'api_secret': apiSecret,
      };

  String get token => '$apiKey:$apiSecret';

  AuthSession toEntity() => AuthSession(
        username: user,
        token: token,
        fullName: fullName,
      );
}
