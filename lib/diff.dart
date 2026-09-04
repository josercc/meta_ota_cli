import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> createDiff({
  required String basePath,
  required String nextPath,
  required String outPath,
  required bool preferBsdiff,
}) async {
  final out = File(outPath);
  out.parent.createSync(recursive: true);

  if (preferBsdiff) {
    final bsdiff = await which('bsdiff');
    if (bsdiff != null) {
      final result = await Process.run(bsdiff, [basePath, nextPath, outPath]);
      if (result.exitCode != 0) {
        stderr.writeln(result.stderr);
        exit(result.exitCode);
      }
      stdout.writeln('Wrote bsdiff patch: $outPath');
      return;
    }
    stderr.writeln('bsdiff not found; writing full next artifact (not a delta).');
  }

  File(nextPath).copySync(outPath);
  final hash = sha256.convert(File(outPath).readAsBytesSync());
  stdout.writeln('Wrote $outPath (sha256=$hash)');
  stdout.writeln(
    'Note: Shorebird updater expects Shorebird-format binary diffs. '
    'Prefer `meta_ota patch` (Shorebird + upload).',
  );
}

Future<String?> which(String cmd) async {
  final result = await Process.run(
    Platform.isWindows ? 'where' : 'which',
    [cmd],
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) return null;
  final out = (result.stdout as String).trim();
  if (out.isEmpty) return null;
  return out.split(RegExp(r'\r?\n')).first.trim();
}
