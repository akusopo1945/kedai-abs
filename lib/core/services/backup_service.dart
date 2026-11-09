import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/pos_provider.dart';

/// Backups are plain JSON files shared through the Android share sheet
/// (Google Drive, WhatsApp, etc.), so no storage permission is needed.
class BackupService {
  BackupService._();

  static Future<XFile> createBackupFile(PosProvider pos) async {
    final json = await pos.exportBackupJson();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'kedai-abs-backup-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(json, flush: true);
    return XFile(file.path, name: name, mimeType: 'application/json');
  }

  static Future<ShareResult> shareBackup(
    PosProvider pos, {
    String? message,
  }) async {
    final file = await createBackupFile(pos);
    return SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: message,
        subject: 'Cadangan Kedai POS ${file.name}',
      ),
    );
  }

  /// Returns the selected file's content, or null when the user cancels.
  static Future<String?> pickBackupFile() async {
    final file = await openFile();
    if (file == null) return null;
    return file.readAsString();
  }
}
