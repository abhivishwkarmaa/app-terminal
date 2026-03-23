import 'host_model.dart';

enum PendingSyncAction { upsert, delete }

extension PendingSyncActionX on PendingSyncAction {
  String get storageValue {
    switch (this) {
      case PendingSyncAction.upsert:
        return 'upsert';
      case PendingSyncAction.delete:
        return 'delete';
    }
  }

  static PendingSyncAction fromStorageValue(String? value) {
    switch (value) {
      case 'delete':
        return PendingSyncAction.delete;
      case 'upsert':
      default:
        return PendingSyncAction.upsert;
    }
  }
}

class PendingSyncOperation {
  final String hostId;
  final PendingSyncAction action;
  final HostModel? host;

  const PendingSyncOperation({
    required this.hostId,
    required this.action,
    this.host,
  });

  Map<String, dynamic> toJson() {
    return {
      'host_id': hostId,
      'action': action.storageValue,
      'host': host?.toJson(),
    };
  }

  factory PendingSyncOperation.fromJson(Map<String, dynamic> json) {
    final hostJson = json['host'];
    return PendingSyncOperation(
      hostId: (json['host_id'] ?? '').toString(),
      action: PendingSyncActionX.fromStorageValue(json['action']?.toString()),
      host: hostJson is Map<String, dynamic>
          ? HostModel.fromJson(hostJson)
          : hostJson is Map
          ? HostModel.fromJson(Map<String, dynamic>.from(hostJson))
          : null,
    );
  }
}
