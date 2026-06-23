import 'package:dio/dio.dart';

import '../../../core/sync/op_submitter.dart';
import '../../../core/sync/pending_operation.dart';

const String kAssetMovementOpType = 'asset_movement';
const String kAssetRepairOpType = 'asset_repair';
const String kMaintenanceLogOpType = 'maintenance_log';

/// Shared envelope handling for the asset write endpoints. Mirrors
/// TransferOpSubmitter: VALIDATION_* → fatal, 5xx/network → retryable.
Future<SubmitResult> _post(Dio dio, String path, PendingOperation op) async {
  try {
    final response =
        await dio.post<Map<String, dynamic>>(path, data: op.payload);
    final envelope = response.data?['message'];
    if (envelope is! Map) {
      return const SubmitRetryable('Unexpected response shape.');
    }
    final body = envelope.cast<String, dynamic>();
    if (body['ok'] == true) {
      final data = body['data'] as Map?;
      return SubmitSuccess((data?['name'] as String?) ?? '');
    }
    final code = body['code'] as String? ?? '';
    final message =
        body['message'] as String? ?? 'Server rejected the request.';
    return code.startsWith('VALIDATION_')
        ? SubmitFatal(message)
        : SubmitRetryable(message);
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    if (status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429) {
      return SubmitFatal(e.message ?? 'HTTP $status');
    }
    return SubmitRetryable(e.message ?? 'Network error.');
  } catch (e) {
    return SubmitRetryable(e.toString());
  }
}

class AssetMovementOpSubmitter implements OpSubmitter {
  final Dio dio;
  AssetMovementOpSubmitter(this.dio);

  @override
  String get type => kAssetMovementOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) =>
      _post(dio, '/api/method/bude_api.api.assets.create_asset_movement', op);
}

class AssetRepairOpSubmitter implements OpSubmitter {
  final Dio dio;
  AssetRepairOpSubmitter(this.dio);

  @override
  String get type => kAssetRepairOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) =>
      _post(dio, '/api/method/bude_api.api.assets.create_asset_repair', op);
}

class MaintenanceLogOpSubmitter implements OpSubmitter {
  final Dio dio;
  MaintenanceLogOpSubmitter(this.dio);

  @override
  String get type => kMaintenanceLogOpType;

  @override
  Future<SubmitResult> submit(PendingOperation op) => _post(
        dio,
        '/api/method/bude_api.api.assets.complete_maintenance_log',
        op,
      );
}
