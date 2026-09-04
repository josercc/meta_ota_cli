import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'config.dart';
import 'diff.dart';

/// Ensure Shorebird / FVM are on PATH for child processes.
Map<String, String> shorebirdEnv({
  required String shorebirdHostedUrl,
  Map<String, String>? extra,
}) {
  final home = Platform.environment['HOME'] ?? '';
  final path = [
    p.join(home, 'fvm', 'default', 'bin'),
    p.join(home, '.shorebird', 'bin'),
    Platform.environment['PATH'] ?? '',
  ].join(Platform.isWindows ? ';' : ':');

  return {
    ...Platform.environment,
    'PATH': path,
    'SHOREBIRD_HOSTED_URL': shorebirdHostedUrl,
    ...?extra,
  };
}

Future<String> resolveShorebirdBin() async {
  final found = await which('shorebird');
  if (found != null) return found;
  final home = Platform.environment['HOME'] ?? '';
  final candidate = p.join(home, '.shorebird', 'bin', 'shorebird');
  if (File(candidate).existsSync()) return candidate;
  stderr.writeln(
    'shorebird not found. Install Shorebird CLI and ensure it is on PATH.',
  );
  exit(1);
}

bool hasFlutterVersionFlag(List<String> args) {
  for (final arg in args) {
    if (arg == '--flutter-version' || arg.startsWith('--flutter-version=')) {
      return true;
    }
  }
  return false;
}

String? parseReleaseVersion(List<String> args) {
  String? prev;
  for (final arg in args) {
    if (arg.startsWith('--release-version=')) {
      return arg.substring('--release-version='.length);
    }
    if (prev == '--release-version') return arg;
    if (arg.startsWith('--version=')) {
      return arg.substring('--version='.length);
    }
    if (prev == '--version') return arg;
    prev = arg;
  }
  return null;
}

Future<int> runShorebird({
  required String appDir,
  required String command,
  required String platform,
  required MetaOtaConfig config,
  List<String> extraArgs = const [],
}) async {
  final shorebird = await resolveShorebirdBin();
  final env = shorebirdEnv(shorebirdHostedUrl: config.shorebirdHostedUrl);

  stdout.writeln(
    '==> SHOREBIRD_HOSTED_URL=${config.shorebirdHostedUrl}  (CLI register/upload)',
  );
  stdout.writeln('==> Flutter target: ${config.flutterVersion} (Shorebird cache)');
  stdout.writeln('==> app-dir: $appDir');
  final baseUrl = readShorebirdYamlField(appDir, 'base_url');
  if (baseUrl != null) {
    stdout.writeln('==> shorebird.yaml base_url=$baseUrl (device OTA)');
  } else {
    stdout.writeln(
      '==> (yaml has no base_url; devices will use Shorebird cloud)',
    );
  }

  final args = <String>[command, platform, ...extraArgs];
  if (command == 'release' && !hasFlutterVersionFlag(extraArgs)) {
    args.add('--flutter-version=${config.flutterVersion}');
    stdout.writeln(
      '==> Flutter version: ${config.flutterVersion} (Shorebird cache)',
    );
  } else if (command == 'release') {
    stdout.writeln('==> Flutter version: (from CLI args)');
  } else {
    stdout.writeln(
      '==> patch uses Flutter version registered for this release on Shorebird',
    );
    stdout.writeln(
      '==> To use ${config.flutterVersion}, re-release with that version first',
    );
  }

  final result = await Process.start(
    shorebird,
    args,
    workingDirectory: appDir,
    environment: env,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await result.exitCode;
  if (code != 0) return code;

  await warnIfXcconfigMismatch(
    appDir: appDir,
    expectedFlutter: config.flutterVersion,
    platform: platform,
  );
  return 0;
}

Future<void> warnIfXcconfigMismatch({
  required String appDir,
  required String expectedFlutter,
  required String platform,
}) async {
  final xcconfig = File(p.join(appDir, 'ios', 'Flutter', 'Generated.xcconfig'));
  if (!xcconfig.existsSync()) return;
  final found = readGeneratedFlutterVersion(xcconfig);
  if (found != null && found != expectedFlutter) {
    stdout.writeln('');
    stdout.writeln(
      '警告: Generated.xcconfig 显示本次构建 Flutter=$found',
    );
    stdout.writeln('      但锁定目标是 $expectedFlutter。');
    stdout.writeln(
      '      若手机上的 release 与 patch Flutter 不一致，安装补丁会失败。',
    );
    stdout.writeln(
      '      请先: meta_ota release $platform --app-dir $appDir 并重装真机，再 patch。',
    );
    stdout.writeln('');
  } else if (found != null) {
    stdout.writeln('==> 构建后确认 Flutter=$found');
  }
}

String? readGeneratedFlutterVersion(File xcconfig) {
  final text = xcconfig.readAsStringSync();
  final direct = RegExp(r'^FLUTTER_VERSION=(.*)$', multiLine: true).firstMatch(text);
  if (direct != null) return direct.group(1)!.trim();

  final defines = RegExp(r'^DART_DEFINES=(.*)$', multiLine: true).firstMatch(text);
  if (defines != null) {
    for (final part in defines.group(1)!.split(',')) {
      try {
        final s = utf8.decode(base64Decode(part.trim()));
        if (s.startsWith('FLUTTER_VERSION=')) {
          return s.split('=').skip(1).join('=');
        }
      } catch (_) {}
    }
  }

  final root = RegExp(r'^FLUTTER_ROOT=(.*)$', multiLine: true).firstMatch(text);
  if (root != null) {
    final r = root.group(1)!;
    if (r.contains('cac82be5c099')) return '3.41.9';
    if (r.contains('e16cf749ccaa')) return '3.47.2';
  }
  return null;
}
