import 'package:file_selector/file_selector.dart';

import '../domains/engine_diagnostics.dart';

abstract interface class DiagnosticArchiveSaver {
  Future<String?> save(DiagnosticArchive archive);
}

class SystemDiagnosticArchiveSaver implements DiagnosticArchiveSaver {
  const SystemDiagnosticArchiveSaver();

  @override
  Future<String?> save(DiagnosticArchive archive) async {
    const type = XTypeGroup(
      label: 'ZIP archive',
      extensions: <String>['zip'],
      mimeTypes: <String>['application/zip'],
      uniformTypeIdentifiers: <String>['public.zip-archive'],
    );
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[type],
      suggestedName: archive.filename,
      canCreateDirectories: true,
    );
    if (location == null) return null;
    final file = XFile.fromData(
      archive.bytes,
      mimeType: 'application/zip',
      name: archive.filename,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}
