import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/bt_diagnostics.dart';
import '../../../domains/download_task.dart';
import '../../../services/bt_diagnostics_service.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import 'task_detail_controller.dart';

class TaskDetailView extends GetView<TaskDetailController> {
  const TaskDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return DownpeedAppShell(
      selectedDestination: AppDestination.tasks,
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
                  actionError: controller.deleteErrorMessage.value,
                  diagnosticsService: controller.btDiagnostics,
                  diagnosticsExpanded: controller.diagnosticsExpanded.value,
                  onToggleDiagnostics: controller.toggleDiagnostics,
                  onPause: controller.pause,
                  onResume: controller.resume,
                  onRetry: controller.retry,
                  onCancel: controller.cancel,
                  onDelete: controller.delete,
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
    this.actionError,
    this.diagnosticsService,
    this.diagnosticsExpanded = false,
    this.onToggleDiagnostics,
    this.onClose,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onCancel,
    required this.onDelete,
    required this.onOpenFile,
    required this.onRevealFile,
  });

  final DownloadTask task;
  final bool acting;
  final bool desktopActionsSupported;
  final bool fileActionActing;
  final String? fileActionError;
  final String? actionError;
  final BTDiagnosticsService? diagnosticsService;
  final bool diagnosticsExpanded;
  final VoidCallback? onToggleDiagnostics;
  final VoidCallback? onClose;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onOpenFile;
  final VoidCallback onRevealFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final statusColor = taskStateColor(context, task.state);
    final progressPercent = task.total > 0
        ? '${(task.progress * 100).round()}%'
        : '—';
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SingleChildScrollView(
      key: ValueKey('task-detail-${task.id}'),
      padding: EdgeInsets.all(
        textScale >= 1.6
            ? DownpeedThemeTokens.compactPagePadding
            : DownpeedThemeTokens.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            taskStateLabel(task.state),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('close-task-inspector'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(DownpeedIcons.close),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nKeys.taskProgress.tr,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      taskProgressText(task),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    progressPercent,
                    key: ValueKey('task-detail-progress-${task.id}'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (task.state == DownloadTaskState.downloading) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${formatBytes(task.speedBps)}/s',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 10,
            child: TransferTrack(progress: task.progress, color: statusColor),
          ),
          const SizedBox(height: 18),
          _TaskActions(
            task: task,
            acting: acting,
            desktopActionsSupported: desktopActionsSupported,
            fileActionActing: fileActionActing,
            onPause: onPause,
            onResume: onResume,
            onRetry: onRetry,
            onCancel: onCancel,
            onOpenFile: onOpenFile,
            onRevealFile: onRevealFile,
          ),
          if (fileActionError != null) ...[
            const SizedBox(height: 16),
            _TaskErrorNotice(
              key: ValueKey('file-action-error-${task.id}'),
              message: fileActionError!,
            ),
          ],
          if (actionError != null) ...[
            const SizedBox(height: 16),
            _TaskErrorNotice(
              key: ValueKey('task-action-error-${task.id}'),
              message: actionError!,
            ),
          ],
          if (task.error != null) ...[
            const SizedBox(height: 16),
            _TaskErrorNotice(message: taskErrorMessage(task)),
          ],
          const SizedBox(height: 24),
          _DetailSectionLabel(label: L10nKeys.taskDetails.tr),
          const SizedBox(height: 6),
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
          if (task.protocol == DownloadProtocol.bt) ...[
            _DetailRow(
              label: L10nKeys.taskProtocol.tr,
              value: L10nKeys.taskProtocolBT.tr,
              icon: DownpeedIcons.torrentFile,
            ),
            _DetailRow(
              label: L10nKeys.taskConnections.tr,
              value: '${task.connections}',
              icon: DownpeedIcons.connections,
            ),
            const SizedBox(height: 14),
            _BTDiagnosticsSection(
              task: task,
              service: diagnosticsService,
              expanded: diagnosticsExpanded,
              onToggle: onToggleDiagnostics,
            ),
          ],
          _DetailRow(
            label: L10nKeys.taskCreated.tr,
            value: DateFormat(
              'yyyy-MM-dd  HH:mm',
            ).format(task.createdAt.toLocal()),
            icon: DownpeedIcons.clock,
            last: true,
          ),
          if (task.isTerminal) ...[
            const SizedBox(height: 22),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('detail-delete-${task.id}'),
                onPressed: acting ? null : onDelete,
                icon: Icon(
                  DownpeedIcons.delete,
                  color: acting ? null : colors.danger,
                ),
                label: Text(
                  L10nKeys.taskDelete.tr,
                  style: TextStyle(color: acting ? null : colors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.downpeedColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _TaskErrorNotice extends StatelessWidget {
  const _TaskErrorNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.06),
        border: Border.all(color: colors.danger.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(DownpeedIcons.issues, size: 15, color: colors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BTDiagnosticsSection extends StatelessWidget {
  const _BTDiagnosticsSection({
    required this.task,
    required this.service,
    required this.expanded,
    required this.onToggle,
  });

  final DownloadTask task;
  final BTDiagnosticsService? service;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final diagnostics = service?.forTask(task.id);
    final loading = service?.isLoading(task.id) ?? false;
    final error = service?.errorFor(task.id);
    return Container(
      key: ValueKey('bt-diagnostics-${task.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('toggle-bt-diagnostics-${task.id}'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
              child: Row(
                children: [
                  Icon(DownpeedIcons.connections, color: colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10nKeys.taskBTDiagnostics.tr,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          L10nKeys.taskBTDiagnosticsBody.tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: const Icon(DownpeedIcons.expand),
                    ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: colors.border),
            if (error != null && diagnostics == null)
              _BTDiagnosticsError(
                taskId: task.id,
                onRetry: () => service?.refresh(task.id),
              )
            else if (diagnostics == null)
              const SizedBox(height: 72)
            else
              _BTDiagnosticsBody(diagnostics: diagnostics),
          ],
        ],
      ),
    );
  }
}

class _BTDiagnosticsError extends StatelessWidget {
  const _BTDiagnosticsError({required this.taskId, required this.onRetry});

  final String taskId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              L10nKeys.taskBTDiagnosticsError.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.downpeedColors.danger,
              ),
            ),
          ),
          TextButton(
            key: ValueKey('retry-bt-diagnostics-$taskId'),
            onPressed: onRetry,
            child: Text(L10nKeys.taskBTRefresh.tr),
          ),
        ],
      ),
    );
  }
}

class _BTDiagnosticsBody extends StatelessWidget {
  const _BTDiagnosticsBody({required this.diagnostics});

  final BTDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final connections = diagnostics.connections;
    final traffic = diagnostics.traffic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: diagnostics.live ? colors.success : colors.textMuted,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                diagnostics.live
                    ? L10nKeys.taskBTLive.tr
                    : L10nKeys.taskBTStopped.tr,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: diagnostics.live ? colors.success : colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _BTMetric(
                label: L10nKeys.taskBTConfigured.tr,
                value: '${connections.configured}',
              ),
              _BTMetric(
                label: L10nKeys.taskBTPeerLimit.tr,
                value: '${diagnostics.policy.maxPeerConnections}',
              ),
              _BTMetric(
                label: L10nKeys.taskBTConnected.tr,
                value: '${connections.connected}',
              ),
              _BTMetric(
                label: L10nKeys.taskBTPending.tr,
                value: '${connections.pending}',
              ),
              _BTMetric(
                label: L10nKeys.taskBTHalfOpen.tr,
                value: '${connections.halfOpen}',
              ),
              _BTMetric(
                label: L10nKeys.taskBTUsefulTraffic.tr,
                value: formatBytes(traffic.usefulBytes),
              ),
              _BTMetric(
                label: L10nKeys.taskBTUploadTraffic.tr,
                value: formatBytes(traffic.uploadedBytes),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Text(
            L10nKeys.taskBTPeers.tr,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            L10nKeys.taskBTPeerPrivacy.tr,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 9),
          if (diagnostics.peers.isEmpty)
            Text(
              L10nKeys.taskBTNoPeers.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            )
          else
            ...diagnostics.peers.map((peer) => _BTPeerRow(peer: peer)),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(DownpeedIcons.shield, color: colors.textMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nKeys.taskBTPolicy.tr,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      L10nKeys.taskBTExplicitOnly.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${L10nKeys.taskBTPolicyRestricted.tr} · '
                      '${diagnostics.policy.restrictedCapabilitiesDisabled ? L10nKeys.taskBTDisabled.tr : L10nKeys.taskBTUnexpectedEnabled.tr}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: diagnostics.policy.restrictedCapabilitiesDisabled
                            ? colors.textMuted
                            : colors.danger,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BTMetric extends StatelessWidget {
  const _BTMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.downpeedColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BTPeerRow extends StatelessWidget {
  const _BTPeerRow({required this.peer});

  final BTPeerDiagnostics peer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.address,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${peer.client} · ${peer.network}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.downpeedColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatBytes(peer.downloadRateBps)}/s',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
    required this.onRetry,
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
  final VoidCallback onRetry;
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
        if (task.canRetry)
          FilledButton.icon(
            key: ValueKey('detail-retry-${task.id}'),
            onPressed: acting ? null : onRetry,
            icon: const Icon(DownpeedIcons.retry),
            label: Text(L10nKeys.taskRetry.tr),
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
