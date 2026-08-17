import 'package:downpeed_flutter/domains/download_task.dart';
import 'package:downpeed_flutter/services/desktop_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations({
      'zh_CN': {
        'task.fileAction.notFound': '文件已被移动或删除，无法执行此操作。',
        'task.fileAction.unavailable': '系统暂时无法打开这个文件。',
        'task.fileAction.unsupported': '当前平台暂不支持这个文件操作。',
        'notification.downloadComplete': '下载完成',
        'notification.downloadComplete.body': '@fileName 已保存。',
      },
    });
    Get.locale = const Locale('zh', 'CN');
  });

  tearDown(Get.reset);

  test('opens and reveals only completed task paths', () async {
    final platform = _FakeDesktopActions();
    final service = DesktopActionsService(platform: platform);
    final completed = _task(DownloadTaskState.completed);

    await service.openFile(completed);
    await service.revealFile(completed);
    await service.openFile(_task(DownloadTaskState.downloading));

    expect(platform.openedPaths, <String>[completed.filePath]);
    expect(platform.revealedPaths, <String>[completed.filePath]);
  });

  test('normalizes native file errors without exposing raw details', () async {
    final platform = _FakeDesktopActions(openErrorCode: 'file_not_found');
    final service = DesktopActionsService(platform: platform);
    final completed = _task(DownloadTaskState.completed);

    await service.openFile(completed);

    expect(service.errorFor(completed.id), '文件已被移动或删除，无法执行此操作。');
    expect(service.activeTaskIds, isEmpty);
  });

  test('sends localized completion notification metadata', () async {
    final platform = _FakeDesktopActions();
    final service = DesktopActionsService(platform: platform);

    await service.notifyCompleted(_task(DownloadTaskState.completed));

    expect(platform.notificationId, 'task-1');
    expect(platform.notificationTitle, '下载完成');
    expect(platform.notificationBody, 'archive.zip 已保存。');
  });

  test('skips completion notifications when the preference is off', () async {
    final platform = _FakeDesktopActions();
    final service = DesktopActionsService(
      platform: platform,
      completionNotificationsEnabled: () => false,
    );

    await service.notifyCompleted(_task(DownloadTaskState.completed));

    expect(platform.notificationId, isNull);
  });

  test('coalesces automatic completion reveals to the latest task', () async {
    final platform = _FakeDesktopActions();
    final service = DesktopActionsService(
      platform: platform,
      completionNotificationsEnabled: () => false,
      revealCompletedFileEnabled: () => true,
      completionRevealDelay: Duration.zero,
    );
    addTearDown(service.onClose);

    await Future.wait(<Future<void>>[
      service.handleCompleted(
        _task(DownloadTaskState.completed, id: 'task-1', fileName: 'first.zip'),
      ),
      service.handleCompleted(
        _task(
          DownloadTaskState.completed,
          id: 'task-2',
          fileName: 'second.zip',
        ),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(platform.revealedPaths, <String>['/tmp/downloads/second.zip']);
  });

  test(
    'automatic reveal is default-off and reports sanitized failures',
    () async {
      final disabledPlatform = _FakeDesktopActions();
      final disabledService = DesktopActionsService(
        platform: disabledPlatform,
        completionRevealDelay: Duration.zero,
      );
      addTearDown(disabledService.onClose);

      await disabledService.handleCompleted(_task(DownloadTaskState.completed));
      await Future<void>.delayed(Duration.zero);
      expect(disabledPlatform.revealedPaths, isEmpty);

      final failingPlatform = _FakeDesktopActions(
        revealErrorCode: 'file_not_found',
      );
      final enabledService = DesktopActionsService(
        platform: failingPlatform,
        completionNotificationsEnabled: () => false,
        revealCompletedFileEnabled: () => true,
        completionRevealDelay: Duration.zero,
      );
      addTearDown(enabledService.onClose);
      final task = _task(DownloadTaskState.completed);

      await enabledService.handleCompleted(task);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(enabledService.errorFor(task.id), '文件已被移动或删除，无法执行此操作。');
    },
  );
}

class _FakeDesktopActions implements DesktopActionsPlatform {
  _FakeDesktopActions({this.openErrorCode, this.revealErrorCode});

  final String? openErrorCode;
  final String? revealErrorCode;
  final openedPaths = <String>[];
  final revealedPaths = <String>[];
  String? notificationId;
  String? notificationTitle;
  String? notificationBody;

  @override
  bool get isSupported => true;

  @override
  Future<void> openFile(String path) async {
    if (openErrorCode case final code?) throw DesktopActionException(code);
    openedPaths.add(path);
  }

  @override
  Future<void> revealFile(String path) async {
    if (revealErrorCode case final code?) {
      throw DesktopActionException(code);
    }
    revealedPaths.add(path);
  }

  @override
  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    notificationId = id;
    notificationTitle = title;
    notificationBody = body;
  }
}

DownloadTask _task(
  DownloadTaskState state, {
  String id = 'task-1',
  String fileName = 'archive.zip',
}) {
  final now = DateTime.utc(2026, 8, 11, 1);
  return DownloadTask(
    id: id,
    url: 'https://example.com/archive.zip',
    finalUrl: 'https://cdn.example.com/archive.zip',
    fileName: fileName,
    saveDirectory: '/tmp/downloads',
    filePath: '/tmp/downloads/$fileName',
    state: state,
    downloaded: state == DownloadTaskState.completed ? 1024 : 512,
    total: 1024,
    speedBps: state == DownloadTaskState.downloading ? 128 : 0,
    createdAt: now,
    updatedAt: now,
    completedAt: state == DownloadTaskState.completed ? now : null,
  );
}
