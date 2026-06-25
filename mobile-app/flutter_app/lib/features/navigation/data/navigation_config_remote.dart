import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';

/// Writes the admin-configured per-role navigation config. Reads ride on
/// `branding.get` (see [Branding.navigation]), so this only handles saves.
class NavigationConfigRemote {
  final Dio dio;
  NavigationConfigRemote(this.dio);

  Future<void> save(Map<String, dynamic> config) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/method/bude_api.api.navigation.save',
        data: {'config_json': jsonEncode(config)},
      );
      final body = response.data?['message'];
      if (body is! Map || body['ok'] != true) {
        throw ServerException(
          (body is Map ? body['message'] as String? : null) ??
              'Failed to save navigation config.',
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const AuthException('Authentication required.');
      }
      throw ServerException(e.message ?? 'Server error.', statusCode: status);
    }
  }
}

final navigationConfigRemoteProvider = Provider<NavigationConfigRemote>(
  (ref) => NavigationConfigRemote(ref.watch(apiClientProvider).dio),
);
