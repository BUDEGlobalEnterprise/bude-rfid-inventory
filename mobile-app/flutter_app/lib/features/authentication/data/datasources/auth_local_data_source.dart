import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/auth_session_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheSession(AuthSessionModel session);
  Future<AuthSessionModel?> getCachedSession();
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const _sessionKey = 'bude.auth.session';
  final FlutterSecureStorage storage;

  AuthLocalDataSourceImpl({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> cacheSession(AuthSessionModel session) async {
    try {
      await storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    } catch (e) {
      throw CacheException('Failed to persist session: $e');
    }
  }

  @override
  Future<AuthSessionModel?> getCachedSession() async {
    try {
      final raw = await storage.read(key: _sessionKey);
      if (raw == null) return null;
      return AuthSessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      throw CacheException('Failed to read session: $e');
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await storage.delete(key: _sessionKey);
    } catch (e) {
      throw CacheException('Failed to clear session: $e');
    }
  }
}
