import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/download_task.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import 'task_detail_controller.dart';

class TaskDetailView extends GetView<TaskDetailController> {
  const TaskDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return DownpeedAppShell(
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _DetailToolbar(onBack: controller.back),
            Expanded(
              child: Obx(() {
                final task = controller.task;
                if (task == null) {
                  return _MissingTask(
                    loading: controller.taskService.isLoading.value,
                  );
                }
                return TaskDetailPanel(
                  task: task,
                  acting: controller.taskService.isActing(task.id),
                  desktopActionsSupported:
                      controller.desktopActions.isSupported,
                  fileActionActing: controller.desktopActions.isActing(task.id),
                  fileActionError: controller.desktopActions.errorFor(task.id),
                  onPause: controller.pause,
                  onResume: controller.resume,
                  onCancel: controller.cancel,
                  onOpenFile: controller.openFile,
                  onRevealFile: controller.revealFile,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailToolbar extends StatelessWidget {
  const _DetailToolbar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.downpeedColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: L10nKeys.createBack.tr,
            onPressed: onBack,
            icon: const Icon(DownpeedIcons.back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              L10nKeys.taskDetails.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskDetailPanel extends StatelessWidget {
  const TaskDetailPanel({
    super.key,
    required this.task,
    required this.acting,
    required this.desktopActionsSupported,
    required this.fileActionActing,
    required this.fileActionError,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onOpenFile,
    required this.onRevealFile,
  });

  final DownloadTask task;
  final bool acting;
  final bool desktopActionsSupported;
  final bool fileActionActing;
  final String? fileActionError;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onOpenFile;
  final VoidCallback onRevealFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final statusColor = taskStateColor(context, task.state);
    return SingleChildScrollView(
      key: ValueKey('task-detail-${task.id}'),
      padding: const EdgeInsets.all(DownpeedThemeTokens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radius,
                  ),
                ),
                child: Icon(
                  taskStateIcon(task.state),
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      task.fileName,
                      key: const ValueKey('task-detail-file-name'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      taskStateLabel(task.state),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TransferTrack(progress: task.progress, color: statusColor),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  taskProgressText(task),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (task.state == DownloadTaskState.downloading)
                Text(
                  '${formatBytes(task.speedBps)}/s',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _TaskActions(
            task: task,
            acting: acting,
            desktopActionsSupported: desktopActionsSupported,
            fileActionActing: fileActionActing,
            onPause: onPause,
            onResume: onResume,
            onCancel: onCancel,
            onOpenFile: onOpenFile,
            onRevealFile: onRevealFile,
          ),
          if (fileActionError != null) ...[
            const SizedBox(height: 12),
            Container(
              key: ValueKey('file-action-error-${task.id}'),
              padding: const EdgeInsets.all(12),
              color: colors.danger.withValues(alpha: 0.07),
              child: Text(
                fileActionError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.danger,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (task.error != null) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              color: colors.danger.withValues(alpha: 0.07),
              child: Text(
                taskErrorMessage(task),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.danger,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          _DetailRow(
            label: L10nKeys.taskDestination.tr,
            value: task.filePath,
            icon: DownpeedIcons.folder,
          ),
          _DetailRow(
            label: L10nKeys.taskSource.tr,
            value: task.finalUrl,
            icon: DownpeedIcons.link,
          ),
          _DetailRow(
            label: L10nKeys.taskCreated.tr,
            value: DateFormat(
              'yyyy-MM-dd  HH:mm',
            ).format(task.createdAt.toLocal()),
            icon: DownpeedIcons.clock,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.task,
    required this.acting,
    required this.desktopActionsSupported,
    required this.fileActionActing,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onOpenFile,
    required this.onRevealFile,
  });

  final DownloadTask task;
  final bool acting;
  final bool desktopActionsSupported;
  final bool fileActionActing;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onOpenFile;
  final VoidCallback onRevealFile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (task.state == DownloadTaskState.completed &&
            desktopActionsSupported) ...[
          FilledButton.icon(
            key: ValueKey('detail-open-file-${task.id}'),
            onPressed: fileActionActing ? null : onOpenFile,
            icon: const Icon(DownpeedIcons.openFile),
            label: Text(L10nKeys.taskOpenFile.tr),
          ),
          OutlinedButton.icon(
            key: ValueKey('detail-reveal-file-${task.id}'),
            onPressed: fileActionActing ? null : onRevealFile,
            icon: const Icon(DownpeedIcons.revealFile),
            label: Text(L10nKeys.taskRevealFile.tr),
          ),
        ],
        if (task.canPause)
          FilledButton.icon(
            key: ValueKey('detail-pause-${task.id}'),
            onPressed: acting ? null : onPause,
            icon: const Icon(DownpeedIcons.pause),
            label: Text(L10nKeys.taskPause.tr),
          ),
        if (task.canResume)
          FilledButton.icon(
            key: ValueKey('detail-resume-${task.id}'),
            onPressed: acting ? null : onResume,
            icon: const Icon(DownpeedIcons.resume),
            label: Text(L10nKeys.taskResume.tr),
          ),
        if (task.canCancel)
          OutlinedButton.icon(
            key: ValueKey('detail-cancel-${task.id}'),
            onPressed: acting ? null : onCancel,
            icon: const Icon(DownpeedIcons.stop),
            label: Text(L10nKeys.taskCancel.tr),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.last = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: DownpeedThemeTokens.iconSize,
            color: colors.textMuted,
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTask extends StatelessWidget {
  const _MissingTask({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          loading ? L10nKeys.tasksLoading.tr : L10nKeys.taskNotFound.tr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.downpeedColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
