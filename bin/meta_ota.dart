import 'dart:io';

import 'package:args/args.dart';
import 'package:meta_ota_cli/meta_ota_cli.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  // Migrate old top-level admin command names with a clear hint.
  final migrated = _maybeMigrateLegacyArgs(args);
  if (migrated != null) {
    stderr.writeln(migrated);
    exit(64);
  }

  final parser = ArgParser()
    ..addOption('api', help: 'Control API base URL (overrides config/env)')
    ..addOption('token', help: 'Admin / API token')
    ..addOption('app-dir', help: 'Flutter app directory (contains shorebird.yaml)')
    ..addOption('flutter-version', help: 'Shorebird Flutter version for release')
    ..addOption('shorebird-hosted-url', help: 'Shorebird cloud API for CLI')
    ..addCommand('config')
    ..addCommand('release')
    ..addCommand('patch')
    ..addCommand('upload')
    ..addCommand('admin')
    ..addCommand('diff');

  parser.commands['config']!
    ..addOption('api')
    ..addOption('token')
    ..addOption('flutter-version')
    ..addOption('shorebird-hosted-url')
    ..addOption('app-dir')
    ..addFlag('project', help: 'Write .meta_ota.json in cwd/app-dir', defaultsTo: false)
    ..addFlag('show', help: 'Print resolved config', negatable: false);

  void addPlatformPositional(ArgParser cmd) {
    // platform is first rest arg; also allow --platform
    cmd
      ..addOption('app-dir', help: 'Flutter app directory (contains shorebird.yaml)')
      ..addOption('api', help: 'Control API base URL')
      ..addOption('token', help: 'Admin / API token')
      ..addOption('flutter-version', help: 'Shorebird Flutter version for release')
      ..addOption('shorebird-hosted-url', help: 'Shorebird cloud API for CLI')
      ..addOption('platform', abbr: 'p', allowed: ['android', 'ios'])
      ..addOption('version', help: 'release_version (for patch/upload)')
      ..addOption('arch', defaultsTo: Platform.environment['META_OTA_ARCH'] ?? 'aarch64')
      ..addOption('release-libapp', help: 'Android release baseline libapp.so')
      ..addOption('patch-libapp', help: 'Patched binary path')
      ..addOption('patch-file', help: 'Existing Shorebird diff.patch')
      ..addOption('hash', help: 'SHA-256 of patched binary')
      ..addFlag('upload', defaultsTo: true, help: 'After patch: upload+promote')
      ..addFlag('no-upload', negatable: false, help: 'Only run shorebird patch');
  }

  addPlatformPositional(parser.commands['release']!);
  addPlatformPositional(parser.commands['patch']!);
  addPlatformPositional(parser.commands['upload']!);

  registerAdminCommands(parser.commands['admin']!);

  parser.commands['diff']!
    ..addOption('base', mandatory: true)
    ..addOption('next', mandatory: true)
    ..addOption('out', mandatory: true)
    ..addFlag('bsdiff', defaultsTo: true);

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stderr.writeln(e);
    _usage();
    exit(64);
  }

  if (results.command == null) {
    _usage();
    exit(0);
  }

  final cmd = results.command!;
  final cmdName = cmd.name!;

  // Resolve config with CLI overrides (subcommand flags win over global).
  String? opt(String name) {
    if (cmd.options.contains(name)) {
      final v = cmd[name];
      if (v is String && v.isNotEmpty) return v;
    }
    if (results.options.contains(name)) {
      final v = results[name];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  final cliAppDir = opt('app-dir');
  final config = MetaOtaConfig.resolve(
    cliApi: opt('api'),
    cliToken: opt('token'),
    cliFlutterVersion: opt('flutter-version'),
    cliShorebirdHostedUrl: opt('shorebird-hosted-url'),
    cliAppDir: cliAppDir,
  );
  final appDir = p.normalize(
    p.absolute(cliAppDir ?? config.appDir ?? Directory.current.path),
  );

  switch (cmdName) {
    case 'config':
      if (cmd['show'] == true) {
        final showCfg = MetaOtaConfig.resolve(
          cliApi: cmd['api'] as String? ?? results['api'] as String?,
          cliToken: cmd['token'] as String? ?? results['token'] as String?,
          cliFlutterVersion:
              cmd['flutter-version'] as String? ?? results['flutter-version'] as String?,
          cliShorebirdHostedUrl: cmd['shorebird-hosted-url'] as String? ??
              results['shorebird-hosted-url'] as String?,
          cliAppDir: cmd['app-dir'] as String? ?? cliAppDir,
        );
        showCfg.printSummary();
        return;
      }
      await MetaOtaConfig.write(
        project: cmd['project'] as bool,
        projectDir: (cmd['app-dir'] as String?) ?? cliAppDir,
        api: cmd['api'] as String?,
        token: cmd['token'] as String?,
        flutterVersion: cmd['flutter-version'] as String?,
        shorebirdHostedUrl: cmd['shorebird-hosted-url'] as String?,
        appDir: cmd['app-dir'] as String?,
      );
      return;

    case 'release':
      final platform = _platformOf(cmd);
      final extra = _passthrough(cmd.rest, platform);
      final code = await runShorebird(
        appDir: appDir,
        command: 'release',
        platform: platform,
        config: config,
        extraArgs: extra,
      );
      exit(code);

    case 'patch':
      final platform = _platformOf(cmd);
      final version = (cmd['version'] as String?) ?? parseReleaseVersion(cmd.rest);
      if (version == null || version.isEmpty) {
        stderr.writeln(
          'patch 需要 --version / --release-version（例如 1.0.0+1）',
        );
        exit(64);
      }
      final extra = _passthrough(cmd.rest, platform);
      if (!extra.any((a) => a.startsWith('--release-version') || a == '--release-version')) {
        extra.add('--release-version=$version');
      }
      final code = await runShorebird(
        appDir: appDir,
        command: 'patch',
        platform: platform,
        config: config,
        extraArgs: extra,
      );
      if (code != 0) exit(code);

      final noUpload = cmd['no-upload'] == true || cmd['upload'] == false;
      if (noUpload) {
        stdout.writeln('==> --no-upload：跳过上传。可稍后: meta_ota upload $platform --version $version');
        return;
      }

      await uploadShorebirdPatch(PatchUploadOptions(
        appDir: appDir,
        platform: platform,
        releaseVersion: version,
        arch: cmd['arch'] as String,
        api: config.api,
        token: config.token,
        patchLibapp: cmd['patch-libapp'] as String?,
        patchFile: cmd['patch-file'] as String?,
        libappHash: cmd['hash'] as String?,
        releaseLibapp: cmd['release-libapp'] as String?,
      ));

    case 'upload':
      final platform = _platformOf(cmd);
      final version = (cmd['version'] as String?) ??
          parseReleaseVersion(cmd.rest) ??
          (cmd.rest.length > 1 ? cmd.rest[1] : null);
      if (version == null || version.isEmpty) {
        stderr.writeln('upload 需要 --version（例如 1.0.0+1）');
        exit(64);
      }
      await uploadShorebirdPatch(PatchUploadOptions(
        appDir: appDir,
        platform: platform,
        releaseVersion: version,
        arch: cmd['arch'] as String,
        api: config.api,
        token: config.token,
        patchLibapp: cmd['patch-libapp'] as String?,
        patchFile: cmd['patch-file'] as String?,
        libappHash: cmd['hash'] as String?,
        releaseLibapp: cmd['release-libapp'] as String?,
      ));

    case 'admin':
      requireToken(config.token);
      final client = MetaOtaClient(api: config.api, token: config.token);
      await runAdminCommand(cmd, client);

    case 'diff':
      await createDiff(
        basePath: cmd['base'] as String,
        nextPath: cmd['next'] as String,
        outPath: cmd['out'] as String,
        preferBsdiff: cmd['bsdiff'] as bool,
      );

    default:
      _usage();
      exit(64);
  }
}

String _platformOf(ArgResults cmd) {
  final opt = cmd['platform'] as String?;
  if (opt != null && opt.isNotEmpty) return opt;
  if (cmd.rest.isNotEmpty) {
    final first = cmd.rest.first;
    if (first == 'android' || first == 'ios') return first;
  }
  return 'android';
}

/// Rest args after stripping the platform positional if present.
List<String> _passthrough(List<String> rest, String platform) {
  if (rest.isNotEmpty && rest.first == platform) {
    return List<String>.from(rest.skip(1));
  }
  return List<String>.from(rest);
}

/// Detect legacy top-level admin commands and tell users the new path.
String? _maybeMigrateLegacyArgs(List<String> args) {
  if (args.isEmpty) return null;
  const legacy = {
    'apps',
    'promote',
    'rollout',
    'rollback',
    'pause',
    'adoption',
  };
  final first = args.first;
  if (legacy.contains(first)) {
    return '已迁移: 请使用 `meta_ota admin ${args.join(' ')}`';
  }
  // Old: meta_ota patch --file ... (API upload)
  if (first == 'patch' && args.contains('--file')) {
    return '已迁移: API 上传请用 `meta_ota admin upload-patch ...`；'
        'Shorebird 打补丁+上传请用 `meta_ota patch android --version ...`（不要传 --file）。';
  }
  // Old: meta_ota release --app-id ...
  if (first == 'release' && args.any((a) => a == '--app-id' || a.startsWith('--app-id='))) {
    return '已迁移: 控制面登记 release 请用 `meta_ota admin upload-release ...`；'
        'Shorebird 构建请用 `meta_ota release android`。';
  }
  return null;
}

void _usage() {
  stdout.writeln('''
meta_ota — Meta Code Push CLI（单一可执行文件）

用户主路径（需本机已安装 Shorebird）:
  meta_ota config --api https://ota.example.com --token <token>
  meta_ota release android --app-dir /path/to/app
  meta_ota patch android --app-dir /path/to/app --version 1.0.0+1
  meta_ota upload android --version 1.0.0+1   # 仅上传已打好的 patch

配置优先级: --api/--token > 环境变量 > .meta_ota.json > ~/.meta_ota/config.json

控制面 API（高级）:
  meta_ota admin apps list|create
  meta_ota admin upload-release|upload-patch|promote|rollout|rollback|pause|adoption

其他:
  meta_ota diff --base ... --next ... --out ...
  meta_ota config --show
  meta_ota config --project --api ...   # 写入项目 .meta_ota.json

环境变量:
  META_OTA_API, META_OTA_TOKEN, META_OTA_FLUTTER_VERSION, SHOREBIRD_HOSTED_URL
''');
}
