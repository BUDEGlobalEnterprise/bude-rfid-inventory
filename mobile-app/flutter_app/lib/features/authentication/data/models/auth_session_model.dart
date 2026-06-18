import '../../domain/auth_session.dart';

class AuthSessionModel {
  final String user;
  final String? fullName;
  final String apiKey;
  final String apiSecret;
  final List<String> roles;
  final String? defaultWarehouse;

  const AuthSessionModel({
    required this.user,
    required this.apiKey,
    required this.apiSecret,
    this.fullName,
    this.roles = const [],
    this.defaultWarehouse,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.whereType<String>().toList()
        : <String>[];
    final dw = json['default_warehouse'] as String?;
    return AuthSessionModel(
      user: json['user'] as String,
      fullName: json['full_name'] as String?,
      apiKey: json['api_key'] as String,
      apiSecret: json['api_secret'] as String,
      roles: roles,
      defaultWarehouse: (dw == null || dw.isEmpty) ? null : dw,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user,
        'full_name': fullName,
        'api_key': apiKey,
        'api_secret': apiSecret,
        'roles': roles,
        'default_warehouse': defaultWarehouse,
      };

  String get token => '$apiKey:$apiSecret';

  AuthSession toEntity() => AuthSession(
        username: user,
        token: token,
        fullName: fullName,
        roles: roles,
        defaultWarehouse: defaultWarehouse,
      );
}
