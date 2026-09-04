/// Device → server patch check (Shorebird updater compatible).
class PatchCheckRequest {
  const PatchCheckRequest({
    required this.appId,
    required this.channel,
    required this.releaseVersion,
    required this.platform,
    required this.arch,
    required this.clientId,
    this.currentPatchNumber,
  });

  final String appId;
  final String channel;
  final String releaseVersion;
  final String platform;
  final String arch;
  final String clientId;
  final int? currentPatchNumber;

  factory PatchCheckRequest.fromJson(Map<String, dynamic> json) {
    return PatchCheckRequest(
      appId: json['app_id'] as String,
      channel: json['channel'] as String? ?? 'stable',
      releaseVersion: json['release_version'] as String,
      platform: json['platform'] as String,
      arch: json['arch'] as String,
      clientId: json['client_id'] as String,
      currentPatchNumber: json['current_patch_number'] as int? ??
          json['patch_number'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'channel': channel,
        'release_version': releaseVersion,
        'platform': platform,
        'arch': arch,
        'client_id': clientId,
        if (currentPatchNumber != null)
          'current_patch_number': currentPatchNumber,
      };
}

class PatchArtifact {
  const PatchArtifact({
    required this.number,
    required this.hash,
    required this.downloadUrl,
    this.hashSignature,
  });

  final int number;
  final String hash;
  final String downloadUrl;
  final String? hashSignature;

  factory PatchArtifact.fromJson(Map<String, dynamic> json) {
    return PatchArtifact(
      number: json['number'] as int,
      hash: json['hash'] as String,
      downloadUrl: json['download_url'] as String,
      hashSignature: json['hash_signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'hash': hash,
        'download_url': downloadUrl,
        if (hashSignature != null) 'hash_signature': hashSignature,
      };
}

class PatchCheckResponse {
  const PatchCheckResponse({
    required this.patchAvailable,
    this.patch,
    this.rolledBackPatchNumbers,
  });

  final bool patchAvailable;
  final PatchArtifact? patch;
  final List<int>? rolledBackPatchNumbers;

  factory PatchCheckResponse.fromJson(Map<String, dynamic> json) {
    return PatchCheckResponse(
      patchAvailable: json['patch_available'] as bool? ?? false,
      patch: json['patch'] == null
          ? null
          : PatchArtifact.fromJson(
              Map<String, dynamic>.from(json['patch'] as Map),
            ),
      rolledBackPatchNumbers: (json['rolled_back_patch_numbers'] as List?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'patch_available': patchAvailable,
        if (patch != null) 'patch': patch!.toJson(),
        if (rolledBackPatchNumbers != null)
          'rolled_back_patch_numbers': rolledBackPatchNumbers,
      };

  static const none = PatchCheckResponse(patchAvailable: false);
}
