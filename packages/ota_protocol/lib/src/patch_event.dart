/// Patch lifecycle events reported by the Shorebird updater.
class PatchEventType {
  static const installSuccess = '__patch_install__';
  static const installFailure = '__patch_install_failure__';
  static const download = '__patch_download__';
  static const updateFailure = '__patch_update_failure__';

  static bool isFailure(String type) =>
      type == installFailure || type == updateFailure;
}

class PatchEvent {
  const PatchEvent({
    required this.appId,
    required this.arch,
    required this.clientId,
    required this.type,
    required this.patchNumber,
    required this.platform,
    required this.releaseVersion,
    required this.timestamp,
    this.message,
  });

  final String appId;
  final String arch;
  final String clientId;
  final String type;
  final int patchNumber;
  final String platform;
  final String releaseVersion;
  final int timestamp;
  final String? message;

  factory PatchEvent.fromJson(Map<String, dynamic> json) {
    return PatchEvent(
      appId: json['app_id'] as String,
      arch: json['arch'] as String,
      clientId: json['client_id'] as String,
      type: json['type'] as String,
      patchNumber: json['patch_number'] as int,
      platform: json['platform'] as String,
      releaseVersion: json['release_version'] as String,
      timestamp: json['timestamp'] as int,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'arch': arch,
        'client_id': clientId,
        'type': type,
        'patch_number': patchNumber,
        'platform': platform,
        'release_version': releaseVersion,
        'timestamp': timestamp,
        'message': message,
      };
}

class CreatePatchEventRequest {
  const CreatePatchEventRequest({required this.event});

  final PatchEvent event;

  factory CreatePatchEventRequest.fromJson(Map<String, dynamic> json) {
    return CreatePatchEventRequest(
      event: PatchEvent.fromJson(
        Map<String, dynamic>.from(json['event'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() => {'event': event.toJson()};
}
