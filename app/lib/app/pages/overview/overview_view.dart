import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/download_task.dart';
import '../../../domains/engine_info.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/engine_status_badge.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import 'overview_controller.dart';

class OverviewView extends GetView<OverviewController> {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return DownpeedAppShell(
      selectedDestination: AppDestination.overview,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverviewHeader(controller: controller),
            Expanded(child: _OverviewBody(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DownpeedThemeTokens.pagePadding,
        14,
        DownpeedThemeTokens.pagePadding,
        13,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      L10nKeys.overviewTitle.tr,
                      key: const ValueKey('overview-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: DownpeedThemeTokens.spaceSm),
                  const EngineStatusBadge(dense: true),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                L10nKeys.overviewSubtitle.tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('overview-refresh'),
                tooltip: L10nKeys.overviewRefresh.tr,
                onPressed: () => unawaited(controller.refresh()),
                icon: const Icon(DownpeedIcons.retry),
              ),
              OutlinedButton.icon(
                key: const ValueKey('overview-paste-link'),
                onPressed: () => unawaited(controller.pasteDownload()),
                icon: const Icon(DownpeedIcons.paste),
                label: Text(L10nKeys.overviewPasteLink.tr),
              ),
              FilledButton.icon(
                key: const ValueKey('overview-new-download'),
                onPressed: () => unawaited(controller.openCreateDownload()),
                icon: const Icon(DownpeedIcons.add),
                label: Text(L10nKeys.overviewNewDownload.tr),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _buildBody(context));

  Widget _buildBody(BuildContext context) {
    final engineState = controller.engineService.state.value;
    final tasks = controller.taskService.tasks.toList(growable: false);
    final horizontalPadding = MediaQuery.sizeOf(context).width < 720
        ? DownpeedThemeTokens.compactPagePadding
        : DownpeedThemeTokens.spaceXl;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        key: const ValueKey('overview-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          24,
          horizontalPadding,
          32,
        ),
        children: [
          _OverviewSummary(controller: controller),
          const SizedBox(height: 28),
          if (engineState == EngineConnectionState.checking && tasks.isEmpty)
            const _OverviewMessage(
              key: ValueKey('overview-loading'),
              icon: DownpeedIcons.engine,
              titleKey: L10nKeys.tasksLoading,
              bodyKey: L10nKeys.networkLoading,
              loading: true,
            )
          else if (engineState == EngineConnectionState.offline &&
              tasks.isEmpty)
            _OverviewMessage(
              key: const ValueKey('overview-offline'),
              icon: DownpeedIcons.issues,
              titleKey: L10nKeys.engineOfflineTitle,
              bodyKey: L10nKeys.engineOfflineBody,
              onRetry: controller.refresh,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final current = _OverviewTaskSection(
                  key: const ValueKey('overview-current-transfers'),
                  title: L10nKeys.overviewCurrentTransfers.tr,
                  subtitle: L10nKeys.overviewCurrentTransfersSubtitle.tr,
                  tasks: controller.currentTasks,
                  emptyTitle: L10nKeys.overviewNoActiveTitle.tr,
                  emptyBody: L10nKeys.overviewNoActiveBody.tr,
                  showLiveTransfer: true,
                  onTaskSelected: controller.openTask,
                  action: TextButton.icon(
                    onPressed: controller.viewAllTasks,
                    icon: const Icon(DownpeedIcons.more),
                    label: Text(L10nKeys.overviewViewAll.tr),
                  ),
                );
                final recent = _OverviewTaskSection(
                  key: const ValueKey('overview-recent-tasks'),
                  title: L10nKeys.overviewRecent.tr,
                  subtitle: L10nKeys.overviewRecentSubtitle.tr,
                  tasks: controller.recentTasks,
                  emptyTitle: L10nKeys.overviewNoRecentTitle.tr,
                  emptyBody: L10nKeys.overviewNoRecentBody.tr,
                  onTaskSelected: controller.openTask,
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [current, const SizedBox(height: 28), recent],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: current),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: recent),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final state = controller.engineService.state.value;
    final info = controller.engineService.info.value;
    return Container(
      key: const ValueKey('overview-summary'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final speed = _OverviewSpeed(
            speed: state == EngineConnectionState.online
                ? controller.totalSpeed
                : null,
            engineLabel: _engineLabel(info),
          );
          final metrics = _OverviewMetrics(
            active: controller.activeCount,
            queued: controller.queuedCount,
            completed: controller.completedCount,
            issues: controller.issueCount,
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                speed,
                Divider(height: 1, color: colors.border),
                metrics,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 310, child: speed),
              Container(width: 1, height: 128, color: colors.border),
              Expanded(child: metrics),
            ],
          );
        },
      ),
    );
  }

  String _engineLabel(EngineInfo? info) {
    if (info == null) return L10nKeys.engineOffline.tr;
    return '${info.name} · ${info.version}';
  }
}

class _OverviewSpeed extends StatelessWidget {
  const _OverviewSpeed({required this.speed, required this.engineLabel});

  final int? speed;
  final String engineLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      constraints: const BoxConstraints(minHeight: 128),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                DownpeedIcons.download,
                size: 16,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  L10nKeys.overviewCurrentSpeed.tr,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            speed == null ? '—' : '${formatBytes(speed!)}/s',
            key: const ValueKey('overview-current-speed'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            engineLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({
    required this.active,
    required this.queued,
    required this.completed,
    required this.issues,
  });

  final int active;
  final int queued;
  final int completed;
  final int issues;

  @override
  Widget build(BuildContext context) {
    final values = <_MetricData>[
      _MetricData(
        'active',
        L10nKeys.overviewActive.tr,
        active,
        DownpeedIcons.active,
        context.downpeedColors.accent,
      ),
      _MetricData(
        'queued',
        L10nKeys.overviewQueued.tr,
        queued,
        DownpeedIcons.clock,
        context.downpeedColors.warning,
      ),
      _MetricData(
        'completed',
        L10nKeys.overviewCompleted.tr,
        completed,
        DownpeedIcons.completed,
        context.downpeedColors.success,
      ),
      _MetricData(
        'issues',
        L10nKeys.overviewIssues.tr,
        issues,
        DownpeedIcons.issues,
        context.downpeedColors.danger,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final itemWidth = constraints.maxWidth / columns;
        return Wrap(
          children: [
            for (var index = 0; index < values.length; index++)
              SizedBox(
                width: itemWidth,
                child: _OverviewMetric(
                  key: ValueKey('overview-metric-${values[index].id}'),
                  data: values[index],
                  rightBorder: index % columns != columns - 1,
                  bottomBorder: columns == 2 && index < values.length - columns,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    super.key,
    required this.data,
    required this.rightBorder,
    required this.bottomBorder,
  });

  final _MetricData data;
  final bool rightBorder;
  final bool bottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          right: rightBorder
              ? BorderSide(color: colors.border)
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(color: colors.border)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 16, color: data.color),
          const SizedBox(height: 9),
          Text(
            '${data.value}',
            key: ValueKey('overview-metric-${data.id}-value'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _OverviewTaskSection extends StatelessWidget {
  const _OverviewTaskSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onTaskSelected,
    this.showLiveTransfer = false,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<DownloadTask> tasks;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<DownloadTask> onTaskSelected;
  final bool showLiveTransfer;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
        const SizedBox(height: 11),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(
              DownpeedThemeTokens.radiusLarge,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: tasks.isEmpty
              ? _OverviewEmpty(title: emptyTitle, body: emptyBody)
              : Column(
                  children: [
                    for (var index = 0; index < tasks.length; index++) ...[
                      _OverviewTaskRow(
                        task: tasks[index],
                        showLiveTransfer: showLiveTransfer,
                        onTap: () => onTaskSelected(tasks[index]),
                      ),
                      if (index != tasks.length - 1)
                        Divider(
                          height: 1,
                          indent: 52,
                          color: colors.border.withValues(alpha: 0.78),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _OverviewTaskRow extends StatelessWidget {
  const _OverviewTaskRow({
    required this.task,
    required this.showLiveTransfer,
    required this.onTap,
  });

  final DownloadTask task;
  final bool showLiveTransfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final stateColor = taskStateColor(context, task.state);
    final speed = task.speedBps > 0 ? '${formatBytes(task.speedBps)}/s' : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('overview-task-${task.id}'),
        onTap: onTap,
        hoverColor: colors.surfaceSubtle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  taskStateIcon(task.state),
                  size: 17,
                  color: stateColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showLiveTransfer && speed != null)
                          Text(
                            speed,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          )
                        else
                          Text(
                            DateFormat(
                              'MM-dd HH:mm',
                            ).format(task.updatedAt.toLocal()),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          taskStateLabel(task.state),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: stateColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 10,
                            child: TransferTrack(
                              progress: task.progress,
                              color: stateColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          task.total > 0
                              ? '${(task.progress * 100).round()}%'
                              : '—',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.textMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(DownpeedIcons.more, size: 15, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewEmpty extends StatelessWidget {
  const _OverviewEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 26),
      child: Column(
        children: [
          Icon(DownpeedIcons.download, size: 19, color: colors.textMuted),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _OverviewMessage extends StatelessWidget {
  const _OverviewMessage({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    this.loading = false,
    this.onRetry,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final bool loading;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 23, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(titleKey.tr, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            bodyKey.tr,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => unawaited(onRetry!()),
              icon: const Icon(DownpeedIcons.retry),
              label: Text(L10nKeys.engineRetry.tr),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.id, this.label, this.value, this.icon, this.color);

  final String id;
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}
