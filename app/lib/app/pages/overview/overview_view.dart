import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/download_task.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/engine_settings.dart';
import '../../../services/engine_settings_service.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import 'overview_controller.dart';

const _dashboardMaxWidth = 1440.0;
const _dashboardGap = 14.0;
const _dashboardCardHeight = 150.0;
const _uploadAccent = Color(0xFF9078E8);
const _downloadAccent = Color(0xFF45C2D3);
const _overviewCardBorderAlpha = 0.56;
const _overviewDividerAlpha = 0.34;

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
    final horizontalPadding = MediaQuery.sizeOf(context).width < 720
        ? DownpeedThemeTokens.compactPagePadding
        : DownpeedThemeTokens.spaceXl;
    final colors = context.downpeedColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        22,
        horizontalPadding,
        18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _dashboardMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10nKeys.overviewTitle.tr,
                    key: const ValueKey('overview-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: DownpeedThemeTokens.textHeading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    L10nKeys.overviewSubtitle.tr,
                    key: const ValueKey('overview-subtitle'),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: DownpeedThemeTokens.textCaption,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              );
              final actions = PopupMenuButton<_OverviewAction>(
                key: const ValueKey('overview-tools'),
                tooltip: L10nKeys.overviewActions.tr,
                icon: const Icon(DownpeedIcons.tools),
                onSelected: (action) {
                  switch (action) {
                    case _OverviewAction.refresh:
                      unawaited(controller.refresh());
                    case _OverviewAction.pasteLink:
                      unawaited(controller.pasteDownload());
                    case _OverviewAction.newDownload:
                      unawaited(controller.openCreateDownload());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_OverviewAction>(
                    key: const ValueKey('overview-refresh'),
                    value: _OverviewAction.refresh,
                    child: _OverviewMenuItem(
                      icon: DownpeedIcons.retry,
                      label: L10nKeys.overviewRefresh.tr,
                    ),
                  ),
                  PopupMenuItem<_OverviewAction>(
                    key: const ValueKey('overview-paste-link'),
                    value: _OverviewAction.pasteLink,
                    child: _OverviewMenuItem(
                      icon: DownpeedIcons.paste,
                      label: L10nKeys.overviewPasteLink.tr,
                    ),
                  ),
                  PopupMenuItem<_OverviewAction>(
                    key: const ValueKey('overview-new-download'),
                    value: _OverviewAction.newDownload,
                    child: _OverviewMenuItem(
                      icon: DownpeedIcons.add,
                      label: L10nKeys.overviewNewDownload.tr,
                    ),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: DownpeedThemeTokens.spaceMd),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _OverviewAction { refresh, pasteLink, newDownload }

class _OverviewMenuItem extends StatelessWidget {
  const _OverviewMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: DownpeedThemeTokens.iconSize),
        const SizedBox(width: DownpeedThemeTokens.spaceSm),
        Text(label),
      ],
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
          22,
          horizontalPadding,
          32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _dashboardMaxWidth),
              child: _buildContent(context, engineState, tasks),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    EngineConnectionState engineState,
    List<DownloadTask> tasks,
  ) {
    final summary = _OverviewSummary(controller: controller);
    if (engineState == EngineConnectionState.checking && tasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          const SizedBox(height: 18),
          const _OverviewMessage(
            key: ValueKey('overview-loading'),
            icon: DownpeedIcons.engine,
            titleKey: L10nKeys.tasksLoading,
            bodyKey: L10nKeys.networkLoading,
            loading: true,
          ),
        ],
      );
    }
    if (engineState == EngineConnectionState.offline && tasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          const SizedBox(height: 18),
          _OverviewMessage(
            key: const ValueKey('overview-offline'),
            icon: DownpeedIcons.issues,
            titleKey: L10nKeys.engineOfflineTitle,
            bodyKey: L10nKeys.engineOfflineBody,
            onRetry: controller.refresh,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summary,
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final current = _OverviewTaskSection(
              key: const ValueKey('overview-current-transfers'),
              title: L10nKeys.overviewCurrentTransfers.tr,
              subtitle: L10nKeys.overviewCurrentTransfersSubtitle.tr,
              tasks: controller.currentTasks,
              emptyTitle: L10nKeys.overviewNoActiveTitle.tr,
              emptyBody: L10nKeys.overviewNoActiveBody.tr,
              metrics: _OverviewMetrics(
                active: controller.activeCount,
                queued: controller.queuedCount,
                completed: controller.completedCount,
                issues: controller.issueCount,
              ),
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
                children: [current, const SizedBox(height: 18), recent],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: current),
                const SizedBox(width: _dashboardGap),
                Expanded(flex: 2, child: recent),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _OverviewActivity(tasks: tasks),
      ],
    );
  }
}

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.isRegistered<EngineSettingsService>()
        ? EngineSettingsService.to
        : null;
    if (settingsService == null) {
      return _buildSummary(context, null);
    }
    return Obx(() => _buildSummary(context, settingsService.settings.value));
  }

  Widget _buildSummary(BuildContext context, EngineSettings? settings) {
    final state = controller.engineService.state.value;
    final info = controller.engineService.info.value;
    return Container(
      key: const ValueKey('overview-summary'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1080
              ? 4
              : constraints.maxWidth >= 620
              ? 2
              : 1;
          final cardWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - _dashboardGap * (columns - 1)) /
                    columns;
          final cards = <Widget>[
            _EngineSummaryCard(state: state, info: info),
            _LimitSummaryCard(settings: settings),
            _RateSummaryCard(
              label: L10nKeys.networkUpload.tr,
              icon: DownpeedIcons.upload,
              value: '0 B/s',
              footer: L10nKeys.networkDisabled.tr,
              accent: _uploadAccent,
            ),
            _RateSummaryCard(
              key: const ValueKey('overview-download-card'),
              label: L10nKeys.overviewCurrentSpeed.tr,
              icon: DownpeedIcons.download,
              value: state == EngineConnectionState.online
                  ? '${formatBytes(controller.totalSpeed)}/s'
                  : '—',
              valueKey: const ValueKey('overview-current-speed'),
              footer: info == null
                  ? L10nKeys.engineOffline.tr
                  : '${info.name} · ${info.version}',
              accent: _downloadAccent,
            ),
          ];
          return Wrap(
            spacing: _dashboardGap,
            runSpacing: _dashboardGap,
            children: [
              for (final card in cards) SizedBox(width: cardWidth, child: card),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: _dashboardCardHeight,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(
            color: colors.border.withValues(alpha: _overviewCardBorderAlpha),
          ),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
              child: child,
            ),
            if (accent != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: accent!,
                  child: const SizedBox(height: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCardHeader extends StatelessWidget {
  const _DashboardCardHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EngineSummaryCard extends StatelessWidget {
  const _EngineSummaryCard({required this.state, required this.info});

  final EngineConnectionState state;
  final EngineInfo? info;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final (label, statusColor) = switch (state) {
      EngineConnectionState.checking => (
        L10nKeys.engineChecking.tr,
        colors.warning,
      ),
      EngineConnectionState.online => (
        L10nKeys.engineOnline.tr,
        colors.success,
      ),
      EngineConnectionState.offline => (
        L10nKeys.engineOffline.tr,
        colors.danger,
      ),
    };
    final engineInfo = info;
    final engineLabel = engineInfo == null
        ? L10nKeys.engineOffline.tr
        : '${engineInfo.name} · ${engineInfo.version}';
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DashboardCardHeader(
            icon: DownpeedIcons.engine,
            label: L10nKeys.networkEngine.tr,
            trailing: Icon(
              DownpeedIcons.info,
              size: 15,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Text(
                  engineLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              _StatusDot(color: statusColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitSummaryCard extends StatelessWidget {
  const _LimitSummaryCard({required this.settings});

  final EngineSettings? settings;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final scheduler = settings?.scheduler;
    final value = scheduler == null
        ? '—'
        : scheduler.downloadRateLimit == 0
        ? L10nKeys.networkUnlimited.tr
        : '${formatBytes(scheduler.downloadRateLimit)}/s';
    final footer = scheduler == null
        ? L10nKeys.networkUnavailable.tr
        : L10nKeys.networkScheduler.tr;
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DashboardCardHeader(
            icon: DownpeedIcons.speedLimit,
            label: L10nKeys.networkDownloadRateLimit.tr,
            trailing: Icon(
              DownpeedIcons.settings,
              size: 15,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 17),
          Text(
            footer,
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

class _RateSummaryCard extends StatelessWidget {
  const _RateSummaryCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.footer,
    required this.accent,
    this.valueKey,
  });

  final String label;
  final IconData icon;
  final String value;
  final String footer;
  final Color accent;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return _DashboardCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DashboardCardHeader(icon: icon, label: label),
          const SizedBox(height: 13),
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            footer,
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    this.metrics,
    this.showLiveTransfer = false,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<DownloadTask> tasks;
  final String emptyTitle;
  final String emptyBody;
  final ValueChanged<DownloadTask> onTaskSelected;
  final _OverviewMetrics? metrics;
  final bool showLiveTransfer;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _overviewCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action!],
              ],
            ),
          ),
          if (metrics != null) ...[
            metrics!,
            Divider(
              height: 1,
              color: colors.border.withValues(alpha: _overviewDividerAlpha),
            ),
          ],
          if (tasks.isEmpty)
            _OverviewEmpty(title: emptyTitle, body: emptyBody)
          else
            for (var index = 0; index < tasks.length; index++) ...[
              _OverviewTaskRow(
                task: tasks[index],
                showLiveTransfer: showLiveTransfer,
                onTap: () => onTaskSelected(tasks[index]),
              ),
              if (index != tasks.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: colors.border.withValues(alpha: _overviewDividerAlpha),
                ),
            ],
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
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final itemWidth = constraints.maxWidth / columns;
        return Container(
          color: context.downpeedColors.surfaceSubtle.withValues(alpha: 0.22),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            children: [
              for (var index = 0; index < values.length; index++)
                SizedBox(
                  width: itemWidth,
                  child: _OverviewMetric(
                    key: ValueKey('overview-metric-${values[index].id}'),
                    data: values[index],
                    rightBorder: index % columns != columns - 1,
                    bottomBorder:
                        columns == 2 && index < values.length - columns,
                  ),
                ),
            ],
          ),
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
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.fromLTRB(18, 4, 16, 4),
      decoration: BoxDecoration(
        border: Border(
          right: rightBorder
              ? BorderSide(
                  color: colors.border.withValues(alpha: _overviewDividerAlpha),
                )
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(
                  color: colors.border.withValues(alpha: _overviewDividerAlpha),
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 16, color: data.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${data.value}',
                  key: ValueKey('overview-metric-${data.id}-value'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
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
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radius,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  taskStateIcon(task.state),
                  size: 17,
                  color: stateColor,
                ),
              ),
              const SizedBox(width: 12),
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
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: Text(
                            showLiveTransfer && speed != null
                                ? speed
                                : DateFormat(
                                    'MM-dd HH:mm',
                                  ).format(task.updatedAt.toLocal()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: showLiveTransfer && speed != null
                                      ? colors.text
                                      : colors.textMuted,
                                  fontWeight: showLiveTransfer && speed != null
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            taskStateLabel(task.state),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: stateColor,
                                  fontWeight: FontWeight.w500,
                                ),
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
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Icon(
                  DownpeedIcons.more,
                  size: 15,
                  color: colors.textMuted,
                ),
              ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
              ),
              alignment: Alignment.center,
              child: Icon(
                DownpeedIcons.download,
                size: 18,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
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
      ),
    );
  }
}

class _OverviewActivity extends StatelessWidget {
  const _OverviewActivity({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('overview-activity'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _overviewCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L10nKeys.overviewActivity.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(
              L10nKeys.overviewActivitySubtitle.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 16),
            _ActivityHeatmap(tasks: tasks),
          ],
        ),
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 90));
    final dates = List<DateTime>.generate(
      91,
      (index) => start.add(Duration(days: index)),
    );
    final counts = <DateTime, int>{};
    for (final task in tasks) {
      final day = DateUtils.dateOnly(task.updatedAt.toLocal());
      if (!day.isBefore(start) && !day.isAfter(today)) {
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    final maximum = counts.values.fold<int>(0, (current, value) {
      return value > current ? value : current;
    });
    final levels = dates
        .map((date) => _activityLevel(counts[date] ?? 0, maximum))
        .toList(growable: false);
    final hasActivity = maximum > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 28.0;
        const gap = 4.0;
        final availableGridWidth = math.max(
          0,
          constraints.maxWidth - labelWidth - 8,
        );
        final cellSize = ((availableGridWidth - gap * 12) / 13)
            .clamp(6.0, 12.0)
            .toDouble();
        final gridWidth = cellSize * 13 + gap * 12;
        final gridHeight = cellSize * 7 + gap * 6;
        final monthLabels = List<String>.generate(13, (column) {
          final date = dates[column * 7];
          if (column > 0 && date.month == dates[(column - 1) * 7].month) {
            return '';
          }
          return Localizations.localeOf(context).languageCode == 'zh'
              ? '${date.month}月'
              : DateFormat('MMM').format(date);
        });
        final weekdayLabels = [
          '',
          L10nKeys.overviewActivityMonday.tr,
          '',
          L10nKeys.overviewActivityWednesday.tr,
          '',
          L10nKeys.overviewActivityFriday.tr,
          '',
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: labelWidth + 8),
                SizedBox(
                  width: gridWidth,
                  child: Row(
                    children: [
                      for (final label in monthLabels)
                        SizedBox(
                          width: cellSize,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  height: gridHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final label in weekdayLabels)
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: GridView.builder(
                    key: const ValueKey('overview-activity-grid'),
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: dates.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 13,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                        ),
                    itemBuilder: (context, index) => _ActivityCell(
                      date: dates[index],
                      count: counts[dates[index]] ?? 0,
                      level: levels[index],
                      size: cellSize,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasActivity ? '' : L10nKeys.overviewActivityEmpty.tr,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ),
                Text(
                  L10nKeys.overviewActivityLess.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(width: 6),
                for (var level = 0; level <= 4; level++) ...[
                  _ActivityCell(date: today, count: 0, level: level, size: 10),
                  if (level != 4) const SizedBox(width: 4),
                ],
                const SizedBox(width: 6),
                Text(
                  L10nKeys.overviewActivityMore.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  int _activityLevel(int count, int maximum) {
    if (count == 0 || maximum == 0) return 0;
    return (count / maximum * 4).ceil().clamp(1, 4).toInt();
  }
}

class _ActivityCell extends StatelessWidget {
  const _ActivityCell({
    required this.date,
    required this.count,
    required this.level,
    required this.size,
  });

  final DateTime date;
  final int count;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final fill = _activityColor(colors, level);
    return Tooltip(
      message: '${DateFormat('yyyy-MM-dd').format(date)} · $count',
      child: Semantics(
        label: '${DateFormat('yyyy-MM-dd').format(date)}: $count',
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Color _activityColor(DownpeedResolvedColors colors, int level) {
    if (level == 0) return colors.surfaceSubtle;
    final opacity = switch (level) {
      1 => 0.22,
      2 => 0.42,
      3 => 0.66,
      _ => 0.92,
    };
    return Color.lerp(colors.surfaceSubtle, colors.success, opacity)!;
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _overviewCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
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
