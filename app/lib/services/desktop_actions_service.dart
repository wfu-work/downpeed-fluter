import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../configs/localization/l10n_keys.dart';
import '../domains/download_task.dart';

abstract interface class DesktopActionsPlatform {
  bool get isSupported;

  Future<void> openFile(String path);

  Future<void> revealFile(String path);

  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  });
}

class MethodChannelDesktopActions implements DesktopActionsPlatform {
  const MethodChannelDesktopActions()
    : _channel = const MethodChannel('com.xiaoxi.downpeed/desktop_actions');

  final MethodChannel _channel;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  Future<void> openFile(String path) => _invokePath('openFile', path);

  @override
  Future<void> revealFile(String path) => _invokePath('revealFile', path);

  @override
  Future<void> showCompletionNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!isSupported) {
      throw const DesktopActionException('unsupported');
    }
    try {
      await _channel.invokeMethod<void>('showCompletionNotification', {
        'id': id,
        'title': title,
        'body': body,
      });
    } on MissingPluginException {
      throw const DesktopActionException('unsupported');
    } on PlatformException catch (error) {
      throw DesktopActionException(error.code);
    }
  }

  Future<void> _invokePath(String method, String path) async {
    if (!isSupported) {
      throw const DesktopActionException('unsupported');
    }
    if (path.trim().isEmpty || path.contains('\u0000')) {
      throw const DesktopActionException('invalid_argument');
    }
    try {
      await _channel.invokeMethod<void>(method, {'path': path});
    } on MissingPluginException {
      throw const DesktopActionException('unsupported');
    } on PlatformException catch (error) {
      throw DesktopActionException(error.code);
    }
  }
}

class DesktopActionException implements Exception {
  const DesktopActionException(this.code);

  final String code;
}

class DesktopActionsService extends GetxService {
  DesktopActionsService({
    required this.platform,
    bool Function()? completionNotificationsEnabled,
  }) : _completionNotificationsEnabled =
           completionNotificationsEnabled ?? (() => true);

  static DesktopActionsService get to => Get.find<DesktopActionsService>();

  final DesktopActionsPlatform platform;
  final bool Function() _completionNotificationsEnabled;
  final activeTaskIds = <String>{}.obs;
  final errorMessage = RxnString();
  final _feedbackTaskId = RxnString();

  bool get isSupported => platform.isSupported;

  bool isActing(String taskId) => activeTaskIds.contains(taskId);

  String? errorFor(String taskId) =>
      _feedbackTaskId.value == taskId ? errorMessage.value : null;

  Future<void> openFile(DownloadTask task) =>
      _performFileAction(task, platform.openFile);

  Future<void> revealFile(DownloadTask task) =>
      _performFileAction(task, platform.revealFile);

  Future<void> notifyCompleted(DownloadTask task) async {
    if (!isSupported ||
        !_completionNotificationsEnabled() ||
        task.state != DownloadTaskState.completed) {
      return;
    }
    try {
      await platform.showCompletionNotification(
        id: task.id,
        title: L10nKeys.notificationDownloadComplete.tr,
        body: L10nKeys.notificationDownloadCompleteBody.trParams({
          'fileName': task.fileName,
        }),
      );
    } on Object {
      // Notifications are best-effort and must never alter engine task state.
    }
  }

  Future<void> _performFileAction(
    DownloadTask task,
    Future<void> Function(String path) action,
  ) async {
    if (!isSupported ||
        task.state != DownloadTaskState.completed ||
        isActing(task.id)) {
      return;
    }
    activeTaskIds.add(task.id);
    _feedbackTaskId.value = task.id;
    errorMessage.value = null;
    try {
      await action(task.filePath);
    } on DesktopActionException catch (error) {
      errorMessage.value = _messageFor(error.code);
    } on Object {
      errorMessage.value = L10nKeys.taskFileActionUnavailable.tr;
    } finally {
      activeTaskIds.remove(task.id);
    }
  }

  String _messageFor(String code) => switch (code) {
    'file_not_found' => L10nKeys.taskFileActionNotFound.tr,
    'unsupported' => L10nKeys.taskFileActionUnsupported.tr,
    _ => L10nKeys.taskFileActionUnavailable.tr,
  };
}
