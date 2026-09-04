import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'client.dart';

void registerAdminCommands(ArgParser admin) {
  final apps = admin.addCommand('apps')
    ..addCommand('list')
    ..addCommand('create');
  apps.commands['create']!
    ..addOption('name', mandatory: true)
    ..addOption('org', defaultsTo: 'org-default')
    ..addOption('id');

  admin.addCommand('upload-release')
    ..addOption('app-id', mandatory: true)
    ..addOption('version', mandatory: true)
    ..addOption(
      'platform',
      mandatory: true,
      allowed: ['android', 'ios', 'macos', 'windows', 'linux'],
    )
    ..addOption('arch', mandatory: true)
    ..addOption('artifact');

  admin.addCommand('upload-patch')
    ..addOption('app-id', mandatory: true)
    ..addOption('version', mandatory: true, help: 'release_version')
    ..addOption('platform', mandatory: true)
    ..addOption('arch', mandatory: true)
    ..addOption('file', mandatory: true, help: 'Patch binary path')
    ..addOption(
      'hash',
      help: 'SHA-256 of patched libapp.so (not the diff hash)',
    )
    ..addOption('channel', defaultsTo: 'staging')
    ..addOption('rollout', defaultsTo: '100')
    ..addOption('notes')
    ..addOption('signature');

  admin.addCommand('promote')
    ..addOption('patch-id', mandatory: true)
    ..addOption('channel', defaultsTo: 'stable');

  admin.addCommand('rollout')
    ..addOption('patch-id', mandatory: true)
    ..addOption('percent', mandatory: true);

  admin.addCommand('rollback').addOption('patch-id', mandatory: true);

  admin.addCommand('pause')
    ..addOption('patch-id', mandatory: true)
    ..addFlag('resume', negatable: false);

  admin.addCommand('adoption')
    ..addOption('app-id', mandatory: true)
    ..addOption('patch-number');
}

Future<void> runAdminCommand(ArgResults adminCmd, MetaOtaClient client) async {
  final name = adminCmd.command?.name;
  if (name == null) {
    stderr.writeln(
      'Usage: meta_ota admin <apps|upload-release|upload-patch|promote|rollout|rollback|pause|adoption>',
    );
    exit(64);
  }

  switch (name) {
    case 'apps':
      final sub = adminCmd.command!;
      if (sub.command?.name == 'list') {
        stdout.writeln(await client.get('/admin/v1/apps'));
      } else if (sub.command?.name == 'create') {
        final c = sub.command!;
        stdout.writeln(await client.post('/admin/v1/apps', {
          'name': c['name'],
          'organization_id': c['org'],
          if (c['id'] != null) 'id': c['id'],
        }));
      } else {
        stderr.writeln('Usage: meta_ota admin apps list|create');
        exit(64);
      }
    case 'upload-release':
      final c = adminCmd.command!;
      final artifact = c['artifact'] as String?;
      String? artifactPath;
      if (artifact != null) {
        final bytes = File(artifact).readAsBytesSync();
        final rel =
            'releases/${c['app-id']}/${c['version']}/${c['platform']}/${c['arch']}/${p.basename(artifact)}';
        final tmp = await client.post('/admin/v1/artifacts', {
          'relative_path': rel,
          'content_base64': base64Encode(bytes),
        });
        artifactPath = (jsonDecode(tmp) as Map)['path'] as String? ?? rel;
      }
      stdout.writeln(await client.post('/admin/v1/releases', {
        'app_id': c['app-id'],
        'version': c['version'],
        'platform': c['platform'],
        'arch': c['arch'],
        if (artifactPath != null) 'artifact_path': artifactPath,
      }));
    case 'upload-patch':
      final c = adminCmd.command!;
      final file = File(c['file'] as String);
      if (!file.existsSync()) {
        stderr.writeln('File not found: ${file.path}');
        exit(1);
      }
      final bytes = file.readAsBytesSync();
      final hash = c['hash'] as String? ?? sha256.convert(bytes).toString();
      stdout.writeln(await client.post('/admin/v1/patches', {
        'app_id': c['app-id'],
        'release_version': c['version'],
        'platform': c['platform'],
        'arch': c['arch'],
        'channel': c['channel'],
        'rollout_percent': int.parse(c['rollout'] as String),
        'content_base64': base64Encode(bytes),
        'hash': hash,
        if (c['notes'] != null) 'notes': c['notes'],
        if (c['signature'] != null) 'hash_signature': c['signature'],
      }));
    case 'promote':
      final c = adminCmd.command!;
      stdout.writeln(await client.post(
        '/admin/v1/patches/${c['patch-id']}/promote',
        {'channel': c['channel']},
      ));
    case 'rollout':
      final c = adminCmd.command!;
      stdout.writeln(await client.post(
        '/admin/v1/patches/${c['patch-id']}/rollout',
        {'percent': int.parse(c['percent'] as String)},
      ));
    case 'rollback':
      final c = adminCmd.command!;
      stdout.writeln(await client.post(
        '/admin/v1/patches/${c['patch-id']}/rollback',
        {},
      ));
    case 'pause':
      final c = adminCmd.command!;
      stdout.writeln(await client.post(
        '/admin/v1/patches/${c['patch-id']}/pause',
        {'paused': !(c['resume'] as bool)},
      ));
    case 'adoption':
      final c = adminCmd.command!;
      final q = StringBuffer('/admin/v1/adoption?app_id=${c['app-id']}');
      if (c['patch-number'] != null) {
        q.write('&patch_number=${c['patch-number']}');
      }
      stdout.writeln(await client.get(q.toString()));
    default:
      stderr.writeln('Unknown admin command: $name');
      exit(64);
  }
}
