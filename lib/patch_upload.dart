import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'client.dart';
import 'config.dart';

class PatchUploadOptions {
  PatchUploadOptions({
    required this.appDir,
    required this.platform,
    required this.releaseVersion,
    required this.arch,
    required this.api,
    required this.token,
    this.patchLibapp,
    this.patchFile,
    this.libappHash,
    this.releaseLibapp,
    this.promoteChannel = 'stable',
    this.uploadChannel = 'staging',
  });

  final String appDir;
  final String platform;
  final String releaseVersion;
  final String arch;
  final String api;
  final String token;
  final String? patchLibapp;
  final String? patchFile;
  final String? libappHash;
  final String? releaseLibapp;
  final String promoteChannel;
  final String uploadChannel;
}

String androidAbiSubdir(String arch) {
  switch (arch) {
    case 'aarch64':
    case 'arm64':
      return 'arm64-v8a';
    case 'arm':
      return 'armeabi-v7a';
    case 'x86_64':
      return 'x86_64';
    default:
      return arch;
  }
}

String? defaultPatchedBinary(String appDir, String platform, String arch) {
  switch (platform) {
    case 'android':
      final abi = androidAbiSubdir(arch);
      return p.join(
        appDir,
        'build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib',
        abi,
        'libapp.so',
      );
    case 'ios':
      final vmcode = p.join(appDir, 'build', 'out.vmcode');
      if (File(vmcode).existsSync()) return vmcode;
      return p.join(
        appDir,
        'build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App',
      );
    default:
      return null;
  }
}

String defaultPatchBinPath() {
  final home = Platform.environment['HOME'] ?? '';
  return Platform.environment['SHOREBIRD_PATCH_BIN'] ??
      p.join(home, '.shorebird', 'bin', 'cache', 'artifacts', 'patch', 'patch');
}

Future<List<String>> _findNamedRecent(String name) async {
  final roots = <String>{
    Platform.environment['TMPDIR'] ?? '/tmp',
    '/tmp',
    if (Platform.isMacOS) '/var/folders',
  };
  final out = <String>[];
  for (final root in roots) {
    if (!Directory(root).existsSync()) continue;
    final result = await Process.run('find', [
      root,
      '-name',
      name,
      '-mmin',
      '-180',
    ]);
    if (result.exitCode != 0 && (result.stdout as String).trim().isEmpty) {
      continue;
    }
    for (final line in (result.stdout as String).split('\n')) {
      final path = line.trim();
      if (path.isNotEmpty) out.add(path);
    }
  }
  return out;
}

Future<String?> findRecentIosDiff(String appDir) async {
  final anchorPath = p.join(appDir, 'build', 'out.vmcode');
  DateTime? anchor;
  final anchorFile = File(anchorPath);
  if (anchorFile.existsSync()) {
    anchor = await anchorFile.lastModified();
  }

  File? newest;
  DateTime? newestM;
  for (final path in await _findNamedRecent('diff.patch')) {
    final entity = File(path);
    if (!entity.existsSync()) continue;
    final stat = await entity.stat();
    if (stat.size < 1024) continue;
    final m = stat.modified;
    if (anchor != null) {
      final delta = m.difference(anchor).inSeconds.abs();
      if (delta > 900) continue;
    }
    if (newestM == null || !m.isBefore(newestM)) {
      newestM = m;
      newest = entity;
    }
  }
  return newest?.path;
}

Future<String?> findAndroidReleaseBaseline(String patchSoPath) async {
  final patchSize = await File(patchSoPath).length();
  String? best;
  var bestDelta = 1 << 62;

  for (final path in await _findNamedRecent('artifact')) {
    final entity = File(path);
    if (!entity.existsSync()) continue;
    final size = await entity.length();
    final delta = (size - patchSize).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = path;
    }
  }

  if (best != null && bestDelta < 1048576) {
    stdout.writeln(
      '==> 自动匹配 release libapp: $best (size delta=$bestDelta)',
    );
    return best;
  }
  return null;
}

Future<void> uploadShorebirdPatch(PatchUploadOptions opts) async {
  requireToken(opts.token);

  final yamlPath = p.join(opts.appDir, 'shorebird.yaml');
  if (!File(yamlPath).existsSync()) {
    stderr.writeln('未找到 shorebird.yaml: $yamlPath');
    exit(1);
  }

  final appId = Platform.environment['META_OTA_APP_ID'] ??
      readShorebirdYamlField(opts.appDir, 'app_id');
  if (appId == null ||
      appId.isEmpty ||
      appId == '00000000-0000-4000-8000-000000000001') {
    stderr.writeln(
      '错误: shorebird.yaml 中 app_id 无效。请先 shorebird init 或设置 META_OTA_APP_ID。',
    );
    exit(1);
  }

  var patchSo = opts.patchLibapp ??
      Platform.environment['META_OTA_PATCH_LIBAPP'] ??
      defaultPatchedBinary(opts.appDir, opts.platform, opts.arch);

  var libappHash = opts.libappHash ?? Platform.environment['META_OTA_LIBAPP_HASH'];
  if ((libappHash == null || libappHash.isEmpty) &&
      patchSo != null &&
      File(patchSo).existsSync()) {
    libappHash = sha256.convert(await File(patchSo).readAsBytes()).toString();
  }

  var diffFile = opts.patchFile ?? Platform.environment['META_OTA_PATCH_FILE'];
  var deleteDiff = false;

  if (diffFile == null || diffFile.isEmpty) {
    if (opts.platform == 'ios') {
      final found = await findRecentIosDiff(opts.appDir);
      if (found != null) {
        diffFile = found;
        stdout.writeln('==> 使用 iOS 最近 diff: $diffFile');
      }
    }
  }

  if (diffFile == null || diffFile.isEmpty) {
    final patchBin = defaultPatchBinPath();
    if (!File(patchBin).existsSync()) {
      stderr.writeln('未找到 Shorebird patch 工具: $patchBin');
      exit(1);
    }
    if (patchSo == null || !File(patchSo).existsSync()) {
      stderr.writeln(
        '未找到 patch 产物（android: libapp.so / ios: out.vmcode）。请先运行:\n'
        '  meta_ota patch ${opts.platform} --version ${opts.releaseVersion} --app-dir ${opts.appDir}\n'
        '或手动指定 META_OTA_PATCH_FILE / META_OTA_LIBAPP_HASH',
      );
      exit(1);
    }

    var releaseLibapp =
        opts.releaseLibapp ?? Platform.environment['META_OTA_RELEASE_LIBAPP'];
    if ((releaseLibapp == null || releaseLibapp.isEmpty) &&
        opts.platform == 'android') {
      releaseLibapp = await findAndroidReleaseBaseline(patchSo);
    }

    if (releaseLibapp == null || !File(releaseLibapp).existsSync()) {
      stderr.writeln(
        '未找到可上传的 diff。\n'
        'iOS: 请在 shorebird patch 后立刻上传（会抓临时目录 diff.patch），或设置 META_OTA_PATCH_FILE。\n'
        'Android: 可设置 META_OTA_RELEASE_LIBAPP=/path/to/release/libapp.so',
      );
      exit(1);
    }

    final tmp = await File(
      p.join(
        Directory.systemTemp.path,
        'meta_ota_diff_${DateTime.now().millisecondsSinceEpoch}',
      ),
    ).create();
    diffFile = tmp.path;
    deleteDiff = true;
    stdout.writeln('==> 生成 diff: $patchBin');
    final result = await Process.run(patchBin, [releaseLibapp, patchSo, diffFile]);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      stderr.writeln(result.stdout);
      if (deleteDiff) {
        try {
          await File(diffFile).delete();
        } catch (_) {}
      }
      exit(result.exitCode);
    }
  }

  final resolvedDiff = diffFile;
  final diff = File(resolvedDiff);
  if (!diff.existsSync()) {
    stderr.writeln('patch diff 不存在: $resolvedDiff');
    exit(1);
  }
  final diffSize = await diff.length();
  if (diffSize < 32) {
    stderr.writeln('错误: patch diff 过小 ($diffSize bytes)，不是有效的 Shorebird diff。');
    exit(1);
  }
  if (libappHash == null || libappHash.isEmpty) {
    stderr.writeln(
      '错误: 无法计算 patched binary hash。请设置 META_OTA_LIBAPP_HASH 或 META_OTA_PATCH_LIBAPP。',
    );
    exit(1);
  }

  stdout.writeln('==> app_id: $appId');
  stdout.writeln('==> platform: ${opts.platform} / ${opts.arch}');
  stdout.writeln('==> patched binary: ${patchSo ?? "(hash only)"}');
  stdout.writeln('==> diff: $resolvedDiff ($diffSize bytes)');
  stdout.writeln('==> hash: $libappHash');
  stdout.writeln('==> api: ${opts.api}');

  final client = MetaOtaClient(api: opts.api, token: opts.token);
  final bytes = await diff.readAsBytes();
  final created = await client.postJson('/admin/v1/patches', {
    'app_id': appId,
    'release_version': opts.releaseVersion,
    'platform': opts.platform,
    'arch': opts.arch,
    'channel': opts.uploadChannel,
    'rollout_percent': 100,
    'content_base64': base64Encode(bytes),
    'hash': libappHash,
  });
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(created));

  final patchId = created['id']?.toString();
  if (patchId == null || patchId.isEmpty) {
    stderr.writeln('无法解析 patch id（检查 API 是否在运行）');
    exit(1);
  }

  stdout.writeln('==> Promote → ${opts.promoteChannel} (id=$patchId)');
  stdout.writeln(await client.post(
    '/admin/v1/patches/$patchId/promote',
    {'channel': opts.promoteChannel},
  ));

  stdout.writeln('==> 验证 check API…');
  final checkBody = await client.postPublic('/api/v1/patches/check', {
    'app_id': appId,
    'channel': opts.promoteChannel,
    'release_version': opts.releaseVersion,
    'platform': opts.platform,
    'arch': opts.arch,
    'client_id': 'upload-verify',
  });
  stdout.writeln(checkBody);
  try {
    final check = jsonDecode(checkBody) as Map;
    if (check['patch_available'] == true) {
      stdout.writeln('==> 完成。请完全退出 App 再打开验证。');
    } else {
      stdout.writeln(
        '警告: check API 仍未返回 patch。请确认 META_OTA_PUBLIC_BASE_URL 与 shorebird.yaml base_url 一致。',
      );
    }
  } catch (_) {}

  if (deleteDiff) {
    try {
      await File(resolvedDiff).delete();
    } catch (_) {}
  }
}
