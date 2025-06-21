import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/identity_store.dart';

class ExportManager {
  /// Export currently active identity as `.ataraxian`
  static Future<File> exportActiveIdentity({required String key}) async {
    final identity = await IdentityStore.active();
    if (identity == null) {
      throw Exception('NO_ACTIVE_IDENTITY');
    }

    final payload = IdentityStore.buildExport(identity: identity, key: key);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${identity.name}.ataraxian');

    await file.writeAsString(payload);
    return file;
  }

  /// Restore identity from `.ataraxian` contents
  static Future<void> restoreFromFile(File file) async {
    final contents = await file.readAsString();
    await IdentityStore.importFromFile(contents);
  }
}
