class AppRecord {
  const AppRecord({
    required this.id,
    required this.name,
    required this.organizationId,
    this.publicKeyPem,
    this.createdAt,
  });

  final String id;
  final String name;
  final String organizationId;
  final String? publicKeyPem;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'organization_id': organizationId,
        'public_key_pem': publicKeyPem,
        'created_at': createdAt?.toIso8601String(),
      };
}

class ReleaseRecord {
  const ReleaseRecord({
    required this.id,
    required this.appId,
    required this.version,
    required this.platform,
    required this.arch,
    this.artifactPath,
    this.createdAt,
  });

  final String id;
  final String appId;
  final String version;
  final String platform;
  final String arch;
  final String? artifactPath;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'app_id': appId,
        'version': version,
        'platform': platform,
        'arch': arch,
        'artifact_path': artifactPath,
        'created_at': createdAt?.toIso8601String(),
      };
}

class PatchRecord {
  const PatchRecord({
    required this.id,
    required this.appId,
    required this.releaseVersion,
    required this.platform,
    required this.arch,
    required this.number,
    required this.hash,
    required this.channel,
    required this.rolloutPercent,
    required this.rolledBack,
    required this.paused,
    this.hashSignature,
    this.artifactPath,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String appId;
  final String releaseVersion;
  final String platform;
  final String arch;
  final int number;
  final String hash;
  final String? hashSignature;
  final String channel;
  final int rolloutPercent;
  final bool rolledBack;
  final bool paused;
  final String? artifactPath;
  final String? notes;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'app_id': appId,
        'release_version': releaseVersion,
        'platform': platform,
        'arch': arch,
        'number': number,
        'hash': hash,
        'hash_signature': hashSignature,
        'channel': channel,
        'rollout_percent': rolloutPercent,
        'rolled_back': rolledBack,
        'paused': paused,
        'artifact_path': artifactPath,
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
      };
}
