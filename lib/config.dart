import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolved Meta OTA CLI settings.
///
/// Precedence (highest first):
/// 1. Explicit CLI `--api` / `--token` / related flags
/// 2. Environment variables
/// 3. Project `.meta_ota.json` (under [appDir] or cwd)
/// 4. User `~/.meta_ota/config.json`
class MetaOtaConfig {
  MetaOtaConfig({
    required this.api,
    required this.token,
    required this.flutterVersion,
    required this.shorebirdHostedUrl,
    this.appDir,
  });

  final String api;
  final String token;
  final String flutterVersion;
  final String shorebirdHostedUrl;
  final String? appDir;

  static String get userConfigPath =>
      p.join(Platform.environment['HOME'] ?? Directory.current.path, '.meta_ota', 'config.json');

  static String projectConfigPath(String dir) => p.join(dir, '.meta_ota.json');

  static Map<String, dynamic> _readJsonFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return {};
    try {
      final decoded = jsonDecode(f.readAsStringSync());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  /// Load merged config. [cliApi]/[cliToken] etc. are raw CLI values (may be null if not passed).
  static MetaOtaConfig resolve({
    String? cliApi,
    String? cliToken,
    String? cliFlutterVersion,
    String? cliShorebirdHostedUrl,
    String? cliAppDir,
    String? projectDir,
  }) {
    final home = _readJsonFile(userConfigPath);
    final dir = projectDir ??
        cliAppDir ??
        (home['app_dir'] as String?) ??
        Directory.current.path;
    final project = _readJsonFile(projectConfigPath(dir));

    String pick(String key, String? cli, String? env, [String? fallback]) {
      if (cli != null && cli.trim().isNotEmpty) return cli.trim();
      final e = env?.trim();
      if (e != null && e.isNotEmpty) return e;
      final pVal = project[key]?.toString().trim();
      if (pVal != null && pVal.isNotEmpty) return pVal;
      final hVal = home[key]?.toString().trim();
      if (hVal != null && hVal.isNotEmpty) return hVal;
      return fallback ?? '';
    }

    var token = pick(
      'token',
      cliToken,
      Platform.environment['META_OTA_TOKEN'],
    );
    if (token.isEmpty) {
      token = _readAdminTokenFile() ?? '';
    }

    var api = pick(
      'api',
      cliApi,
      Platform.environment['META_OTA_API'],
      'http://127.0.0.1:8080',
    );

    // Prefer shorebird.yaml base_url when api still default and yaml has one.
    if ((cliApi == null || cliApi.isEmpty) &&
        Platform.environment['META_OTA_API'] == null) {
      final yamlBase = readShorebirdYamlField(dir, 'base_url');
      if (yamlBase != null && yamlBase.isNotEmpty) {
        final fromProject = project['api']?.toString().trim() ?? '';
        final fromHome = home['api']?.toString().trim() ?? '';
        if (fromProject.isEmpty && fromHome.isEmpty) {
          api = yamlBase;
        }
      }
    }

    return MetaOtaConfig(
      api: api.replaceAll(RegExp(r'/+$'), ''),
      token: token,
      flutterVersion: pick(
        'flutter_version',
        cliFlutterVersion,
        Platform.environment['META_OTA_FLUTTER_VERSION'],
        '3.41.9',
      ),
      shorebirdHostedUrl: pick(
        'shorebird_hosted_url',
        cliShorebirdHostedUrl,
        Platform.environment['SHOREBIRD_HOSTED_URL'],
        'https://api.shorebird.dev',
      ),
      appDir: dir,
    );
  }

  static String? _readAdminTokenFile() {
    // Walk up from cwd looking for storage/.admin_token (repo layout).
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final f = File(p.join(dir.path, 'storage', '.admin_token'));
      if (f.existsSync()) {
        return f.readAsStringSync().trim();
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Write user or project config (merge with existing).
  static Future<void> write({
    required bool project,
    String? projectDir,
    String? api,
    String? token,
    String? flutterVersion,
    String? shorebirdHostedUrl,
    String? appDir,
  }) async {
    final path = project
        ? projectConfigPath(projectDir ?? Directory.current.path)
        : userConfigPath;
    final existing = _readJsonFile(path);
    if (api != null) existing['api'] = api;
    if (token != null) existing['token'] = token;
    if (flutterVersion != null) existing['flutter_version'] = flutterVersion;
    if (shorebirdHostedUrl != null) {
      existing['shorebird_hosted_url'] = shorebirdHostedUrl;
    }
    if (appDir != null) existing['app_dir'] = appDir;

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(existing)}\n',
    );
    stdout.writeln('Wrote $path');
  }

  void printSummary() {
    stdout.writeln('api: $api');
    stdout.writeln('token: ${token.isEmpty ? "(empty)" : "***"}');
    stdout.writeln('flutter_version: $flutterVersion');
    stdout.writeln('shorebird_hosted_url: $shorebirdHostedUrl');
    stdout.writeln('app_dir: ${appDir ?? "(cwd)"}');
  }
}

/// Minimal YAML field reader for shorebird.yaml (key: value).
String? readShorebirdYamlField(String appDir, String key) {
  final f = File(p.join(appDir, 'shorebird.yaml'));
  if (!f.existsSync()) return null;
  final re = RegExp('^$key:\\s*(.*)\$', multiLine: true);
  final m = re.firstMatch(f.readAsStringSync());
  if (m == null) return null;
  var v = m.group(1)!.trim();
  if ((v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))) {
    v = v.substring(1, v.length - 1);
  }
  return v;
}
