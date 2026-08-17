import 'dart:io';

import 'package:downpeed_flutter/services/preferences_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockDocumentsDirectory(Directory.systemTemp.path);

  test(
    'completion action defaults off and persists the selected value',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'downpeed_preferences_',
      );
      _mockDocumentsDirectory(directory.path);
      addTearDown(() => _cleanupDirectory(directory));
      final storage = GetStorage(
        'preferences_${DateTime.now().microsecondsSinceEpoch}',
        directory.path,
        <String, dynamic>{},
      );
      final service = PreferencesService(storage: storage);

      await service.init();
      expect(
        service.downloadCompletionAction.value,
        DownloadCompletionAction.none,
      );

      await service.setDownloadCompletionAction(
        DownloadCompletionAction.revealFile,
      );

      expect(
        storage.read<String>('downpeed_download_completion_action'),
        'revealFile',
      );
    },
  );

  test(
    'completion action restores known values and rejects unknown values',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'downpeed_preferences_restore_',
      );
      _mockDocumentsDirectory(directory.path);
      addTearDown(() => _cleanupDirectory(directory));
      final knownStorage = GetStorage(
        'preferences_known_${DateTime.now().microsecondsSinceEpoch}',
        directory.path,
        <String, dynamic>{'downpeed_download_completion_action': 'revealFile'},
      );
      final knownService = PreferencesService(storage: knownStorage);
      await knownService.init();
      expect(
        knownService.downloadCompletionAction.value,
        DownloadCompletionAction.revealFile,
      );

      final unknownStorage = GetStorage(
        'preferences_unknown_${DateTime.now().microsecondsSinceEpoch}',
        directory.path,
        <String, dynamic>{
          'downpeed_download_completion_action': 'openAutomatically',
        },
      );
      final unknownService = PreferencesService(storage: unknownStorage);
      await unknownService.init();
      expect(
        unknownService.downloadCompletionAction.value,
        DownloadCompletionAction.none,
      );
    },
  );
}

void _mockDocumentsDirectory(String? path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        path == null ? null : (_) async => path,
      );
}

Future<void> _cleanupDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 2) rethrow;
    }
  }
}
