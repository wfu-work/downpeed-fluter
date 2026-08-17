import 'dart:typed_data';

import 'package:downpeed_flutter/data/clients/engine_client.dart';
import 'package:downpeed_flutter/domains/engine_diagnostics.dart';
import 'package:downpeed_flutter/services/desktop_actions_service.dart';
import 'package:downpeed_flutter/services/diagnostic_archive_saver.dart';
import 'package:downpeed_flutter/services/diagnostics_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stub_engine_client.dart';

void main() {
  test('loads, saves, and reveals a diagnostic archive', () async {
    final saver = _DiagnosticArchiveSaverStub();
    final desktop = _DesktopActionsPlatformStub();
    final service = DiagnosticsService(
      client: const _DiagnosticsEngineClient(),
      archiveSaver: saver,
      desktopActions: desktop,
    );

    await service.load();
    await service.exportArchive();
    await service.revealSavedArchive();

    expect(service.diagnostics.value?.tasks.total, 4);
    expect(saver.savedArchive?.filename, 'downpeed-diagnostics-test.zip');
    expect(
      service.savedArchivePath.value,
      '/tmp/downpeed-diagnostics-test.zip',
    );
    expect(desktop.revealedPaths, <String>[
      '/tmp/downpeed-diagnostics-test.zip',
    ]);
    expect(service.loadErrorMessage.value, isNull);
    expect(service.exportErrorMessage.value, isNull);
  });

  test(
    'exposes load and export failures without creating a saved result',
    () async {
      final service = DiagnosticsService(
        client: const _FailingDiagnosticsEngineClient(),
        archiveSaver: _DiagnosticArchiveSaverStub(),
        desktopActions: _DesktopActionsPlatformStub(),
      );

      await service.load();
      await service.exportArchive();

      expect(service.diagnostics.value, isNull);
      expect(service.loadErrorMessage.value, isNotNull);
      expect(service.exportErrorMessage.value, isNotNull);
      expect(service.savedArchivePath.value, isNull);
      expect(service.isLoading.value, isFalse);
      expect(service.isExporting.value, isFalse);
    },
  );
}

class _DiagnosticsEngineClient extends StubEngineClient {
  const _DiagnosticsEngineClient();

  @override
  Future<EngineDiagnostics> fetchDiagnostics() async => EngineDiagnostics(
    generatedAt: DateTime.utc(2026, 8, 17, 1, 2, 3),
    storage: const DiagnosticStorage(
      dataDirectory: '~/Library/Application Support/Downpeed',
      databasePath: '~/Library/Application Support/Downpeed/tasks.db',
      databaseSizeBytes: 4096,
      databaseAvailable: true,
      logsAvailable: false,
      logPath: '',
    ),
    tasks: const DiagnosticTaskSummary(
      total: 4,
      active: 1,
      queued: 1,
      paused: 0,
      completed: 2,
      failed: 0,
      canceled: 0,
      http: 3,
      bitTorrent: 1,
    ),
    privacy: const DiagnosticPrivacy(
      pathsRedacted: true,
      taskDetailsIncluded: false,
      logsIncluded: false,
    ),
  );

  @override
  Future<DiagnosticArchive> exportDiagnostics() async => DiagnosticArchive(
    filename: 'downpeed-diagnostics-test.zip',
    bytes: Uint8List.fromList(<int>[0x50, 0x4b]),
  );
}

class _FailingDiagnosticsEngineClient extends StubEngineClient {
  const _FailingDiagnosticsEngineClient();

  @override
  Future<EngineDiagnostics> fetchDiagnostics() =>
      throw const EngineClientException('offline', code: 'engine_unreachable');

  @override
  Future<DiagnosticArchive> exportDiagnostics() =>
      throw const EngineClientException(
        'unavailable',
        code: 'diagnostics_unavailable',
      );
}

class _DiagnosticArchiveSaverStub implements DiagnosticArchiveSaver {
  DiagnosticArchive? savedArchive;

  @override
  Future<String?> save(DiagnosticArchive archive) async {
    savedArchive = archive;
    return '/tmp/downpeed-diagnostics-test.zip';
  }
}

class _DesktopActionsPlatformStub implements DesktopActionsPlatform {
  final revealedPaths = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<void> openFile(String path) async {}

  @override
  Future<void> revealFile(String path) async {
    revealedPaths.add(path);
  }

  @override
  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  }) async {}
}
