import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/localization/l10n_keys.dart';
import '../../configs/theme/downpeed_icons.dart';
import '../../configs/theme/downpeed_theme_tokens.dart';
import '../../domains/download_task.dart';

String formatBytes(int value) {
  if (value < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = value.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  final digits = unit == 0 || amount >= 100
      ? 0
      : amount >= 10
      ? 1
      : 2;
  return '${amount.toStringAsFixed(digits)} ${units[unit]}';
}

String taskProgressText(DownloadTask task) => task.total > 0
    ? '${formatBytes(task.downloaded)} / ${formatBytes(task.total)}'
    : L10nKeys.taskUnknownTotal.trParams({
        'downloaded': formatBytes(task.downloaded),
      });

String taskStateLabel(DownloadTaskState state) => switch (state) {
  DownloadTaskState.queued => L10nKeys.taskQueued.tr,
  DownloadTaskState.downloading => L10nKeys.taskDownloading.tr,
  DownloadTaskState.retrying => L10nKeys.taskRetrying.tr,
  DownloadTaskState.paused => L10nKeys.taskPaused.tr,
  DownloadTaskState.completed => L10nKeys.taskCompleted.tr,
  DownloadTaskState.failed => L10nKeys.taskFailed.tr,
  DownloadTaskState.canceled => L10nKeys.taskCanceled.tr,
};

Color taskStateColor(BuildContext context, DownloadTaskState state) {
  final colors = context.downpeedColors;
  return switch (state) {
    DownloadTaskState.queued => colors.textSecondary,
    DownloadTaskState.downloading => colors.accent,
    DownloadTaskState.retrying => colors.warning,
    DownloadTaskState.paused => colors.warning,
    DownloadTaskState.completed => colors.success,
    DownloadTaskState.failed => colors.danger,
    DownloadTaskState.canceled => colors.textMuted,
  };
}

IconData taskStateIcon(DownloadTaskState state) => switch (state) {
  DownloadTaskState.queued => DownpeedIcons.clock,
  DownloadTaskState.downloading => DownpeedIcons.download,
  DownloadTaskState.retrying => DownpeedIcons.retry,
  DownloadTaskState.paused => DownpeedIcons.pause,
  DownloadTaskState.completed => DownpeedIcons.completed,
  DownloadTaskState.failed => DownpeedIcons.issues,
  DownloadTaskState.canceled => DownpeedIcons.stop,
};

String taskErrorMessage(DownloadTask task) => switch (task.error?.code) {
  'destination_exists' => L10nKeys.taskDestinationExists.tr,
  'invalid_destination' => L10nKeys.taskInvalidDestination.tr,
  'remote_rejected' => L10nKeys.taskRemoteRejected.tr,
  'remote_resource_changed' => L10nKeys.taskRemoteChanged.tr,
  'resume_not_supported' => L10nKeys.taskResumeNotSupported.tr,
  'partial_file_changed' => L10nKeys.taskPartialFileChanged.tr,
  'file_consistency_failed' => L10nKeys.taskFileConsistencyFailed.tr,
  'atomic_publish_failed' => L10nKeys.taskAtomicPublishFailed.tr,
  _ => L10nKeys.taskDownloadFailed.tr,
};
