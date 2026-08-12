import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/batch_task_result.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/download_task.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/engine_status_badge.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import '../task_detail/task_detail_view.dart';
import 'task_list_controller.dart';

class TaskListView extends GetView<TaskListController> {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentFilter = controller.filter.value;
      return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
              unawaited(controller.openCreateDownload()),
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
              unawaited(controller.openCreateDownload()),
        },
        child: Focus(
          autofocus: true,
          child: DownpeedAppShell(
            selectedTaskFilter: currentFilter.index,
            onTaskFilterChanged: (index) =>
                controller.setFilter(TaskListFilter.values[index]),
            taskCounts: TaskListFilter.values
                .map(controller.countForFilter)
                .toList(growable: false),
            child: SafeArea(
              left: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TaskToolbar(controller: controller),
                  Expanded(
                    child: switch (controller.engineService.state.value) {
                      EngineConnectionState.checking => const _CheckingState(),
                      EngineConnectionState.online => _ReadyState(
                        controller: controller,
                      ),
                      EngineConnectionState.offline => _OfflineState(
                        controller: controller,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _TaskToolbar extends StatelessWidget {
  const _TaskToolbar({required this.controller});

  final TaskListController controller;

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
          final compact = constraints.maxWidth < 620;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10nKeys.tasksTitle.tr,
                key: const ValueKey('task-toolbar-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 1),
              Text(
                L10nKeys.tasksSubtitle.tr,
                key: const ValueKey('task-toolbar-subtitle'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                SizedBox(
                  width: 210,
                  child: TextField(
                    key: const ValueKey('task-search-field'),
                    controller: controller.searchController,
                    onChanged: controller.updateSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: L10nKeys.tasksSearch.tr,
                      prefixIcon: const Icon(DownpeedIcons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TaskSortButton(controller: controller),
                const SizedBox(width: 6),
              ],
              FilledButton.icon(
                key: const ValueKey('add-download-button'),
                onPressed: controller.openCreateDownload,
                icon: const Icon(DownpeedIcons.add),
                label: Text(L10nKeys.tasksAdd.tr),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('task-search-field'),
                        controller: controller.searchController,
                        onChanged: controller.updateSearch,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: L10nKeys.tasksSearch.tr,
                          prefixIcon: const Icon(DownpeedIcons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TaskSortButton(controller: controller),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _TaskSortButton extends StatelessWidget {
  const _TaskSortButton({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskListSort>(
      key: const ValueKey('task-sort-button'),
      tooltip: L10nKeys.tasksSort.tr,
      initialValue: controller.sort.value,
      onSelected: controller.setSort,
      icon: const Icon(DownpeedIcons.sort),
      itemBuilder: (context) => TaskListSort.values
          .map(
            (value) => PopupMenuItem<TaskListSort>(
              value: value,
              height: DownpeedThemeTokens.controlHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: value == controller.sort.value
                        ? Icon(
                            DownpeedIcons.completed,
                            size: 15,
                            color: context.downpeedColors.accent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 7),
                  Text(_sortLabel(value)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String _sortLabel(TaskListSort value) => switch (value) {
    TaskListSort.newest => L10nKeys.tasksSortNewest.tr,
    TaskListSort.oldest => L10nKeys.tasksSortOldest.tr,
    TaskListSort.name => L10nKeys.tasksSortName.tr,
    TaskListSort.progress => L10nKeys.tasksSortProgress.tr,
    TaskListSort.size => L10nKeys.tasksSortSize.tr,
  };
}

class _ReadyState extends StatelessWidget {
  const _ReadyState({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = controller.taskService;
      final allTasks = service.tasks.toList(growable: false);
      final tasks = controller.visibleTasks;
      final selectedTaskId = controller.selectedTaskId.value;
      service.actionTaskIds.length;
      service.eventErrorMessage.value;
      controller.selectedTaskIds.length;
      controller.batchMessage.value;
      controller.desktopActions.activeTaskIds.length;
      controller.desktopActions.errorMessage.value;
      if (service.isLoading.value && allTasks.isEmpty) {
        return const _LoadingTasks();
      }
      if (service.errorMessage.value != null && allTasks.isEmpty) {
        return _TaskLoadError(controller: controller);
      }
      if (allTasks.isEmpty) return _EmptyTasks(controller: controller);

      return LayoutBuilder(
        builder: (context, constraints) {
          final showInspector = constraints.maxWidth >= 900;
          final selected = selectedTaskId == null
              ? null
              : service.taskById(selectedTaskId);
          final list = _TaskListPane(
            controller: controller,
            tasks: tasks,
            navigateToDetail: !showInspector,
          );
          if (!showInspector) return list;
          return Row(
            children: [
              Expanded(flex: 3, child: list),
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: context.downpeedColors.surfaceRaised,
                  border: Border(
                    left: BorderSide(color: context.downpeedColors.border),
                  ),
                ),
                child: selected == null
                    ? const _NoTaskSelection()
                    : TaskDetailPanel(
                        task: selected,
                        acting: service.isActing(selected.id),
                        desktopActionsSupported:
                            controller.desktopActions.isSupported,
                        fileActionActing: controller.desktopActions.isActing(
                          selected.id,
                        ),
                        fileActionError: controller.desktopActions.errorFor(
                          selected.id,
                        ),
                        onPause: () => controller.pauseTask(selected),
                        onResume: () => controller.resumeTask(selected),
                        onCancel: () => controller.cancelTask(selected),
                        onOpenFile: () => controller.openFile(selected),
                        onRevealFile: () => controller.revealFile(selected),
                      ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _TaskListPane extends StatelessWidget {
  const _TaskListPane({
    required this.controller,
    required this.tasks,
    required this.navigateToDetail,
  });

  final TaskListController controller;
  final List<DownloadTask> tasks;
  final bool navigateToDetail;

  @override
  Widget build(BuildContext context) {
    final eventError = controller.taskService.eventErrorMessage.value;
    final batchMessage = controller.batchMessage.value;
    final fileActionError = controller.desktopActions.errorMessage.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.hasSelection)
          _BatchCommandStrip(controller: controller)
        else
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.downpeedColors.border),
              ),
            ),
            child: Row(
              children: [
                Tooltip(
                  message: L10nKeys.tasksSelectAll.tr,
                  child: Checkbox(
                    key: const ValueKey('select-all-visible'),
                    value: controller.allVisibleSelected,
                    onChanged: tasks.isEmpty
                        ? null
                        : (_) => controller.toggleSelectAllVisible(),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    L10nKeys.tasksCount.trParams({'count': '${tasks.length}'}),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.downpeedColors.textMuted,
                    ),
                  ),
                ),
                if (eventError != null)
                  IconButton(
                    tooltip: eventError,
                    onPressed: controller.retryTasks,
                    icon: const Icon(DownpeedIcons.retry),
                  ),
              ],
            ),
          ),
        if (batchMessage != null)
          Container(
            key: const ValueKey('batch-task-message'),
            padding: const EdgeInsets.symmetric(
              horizontal: DownpeedThemeTokens.pagePadding,
              vertical: 8,
            ),
            color: context.downpeedColors.surfaceSubtle,
            child: Text(
              batchMessage,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.downpeedColors.textSecondary,
              ),
            ),
          ),
        if (fileActionError != null)
          Container(
            key: const ValueKey('file-action-message'),
            padding: const EdgeInsets.symmetric(
              horizontal: DownpeedThemeTokens.pagePadding,
              vertical: 8,
            ),
            color: context.downpeedColors.danger.withValues(alpha: 0.07),
            child: Text(
              fileActionError,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.downpeedColors.danger,
              ),
            ),
          ),
        Expanded(
          child: tasks.isEmpty
              ? const _NoMatchingTasks()
              : RefreshIndicator(
                  onRefresh: controller.retryTasks,
                  child: ListView.builder(
                    key: const ValueKey('task-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _TaskRow(
                        task: task,
                        selected: controller.selectedTaskId.value == task.id,
                        checked: controller.selectedTaskIds.contains(task.id),
                        acting:
                            controller.taskService.isActing(task.id) ||
                            controller.desktopActions.isActing(task.id),
                        desktopActionsSupported:
                            controller.desktopActions.isSupported,
                        onSelectionChanged: () =>
                            controller.toggleTaskSelection(task.id),
                        onTap: () => controller.openTask(
                          task,
                          compact: navigateToDetail,
                        ),
                        onPause: () => controller.pauseTask(task),
                        onResume: () => controller.resumeTask(task),
                        onOpenFile: () => controller.openFile(task),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _BatchCommandStrip extends StatelessWidget {
  const _BatchCommandStrip({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final selectedCount = controller.selectedTaskIds.length;
    return Container(
      key: const ValueKey('batch-command-strip'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Checkbox(
            value: controller.allVisibleSelected
                ? true
                : controller.anyVisibleSelected
                ? null
                : false,
            tristate: true,
            onChanged: (_) => controller.toggleSelectAllVisible(),
          ),
          Text(
            L10nKeys.tasksSelected.trParams({'count': '$selectedCount'}),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TextButton(
            onPressed: controller.clearSelection,
            child: Text(L10nKeys.tasksClearSelection.tr),
          ),
          OutlinedButton.icon(
            key: const ValueKey('batch-pause-button'),
            onPressed: controller.canBatch(BatchTaskAction.pause)
                ? () => controller.performBatch(BatchTaskAction.pause)
                : null,
            icon: const Icon(DownpeedIcons.pause),
            label: Text(L10nKeys.tasksBatchPause.tr),
          ),
          OutlinedButton.icon(
            key: const ValueKey('batch-resume-button'),
            onPressed: controller.canBatch(BatchTaskAction.resume)
                ? () => controller.performBatch(BatchTaskAction.resume)
                : null,
            icon: const Icon(DownpeedIcons.resume),
            label: Text(L10nKeys.tasksBatchResume.tr),
          ),
          TextButton.icon(
            key: const ValueKey('batch-cancel-button'),
            onPressed: controller.canBatch(BatchTaskAction.cancel)
                ? () => controller.performBatch(BatchTaskAction.cancel)
                : null,
            icon: Icon(DownpeedIcons.stop, color: colors.danger),
            label: Text(
              L10nKeys.tasksBatchCancel.tr,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatchingTasks extends StatelessWidget {
  const _NoMatchingTasks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DownpeedThemeTokens.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              DownpeedIcons.search,
              size: 20,
              color: context.downpeedColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              L10nKeys.tasksNoMatchesTitle.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              L10nKeys.tasksNoMatchesBody.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.downpeedColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.selected,
    required this.checked,
    required this.acting,
    required this.desktopActionsSupported,
    required this.onSelectionChanged,
    required this.onTap,
    required this.onPause,
    required this.onResume,
    required this.onOpenFile,
  });

  final DownloadTask task;
  final bool selected;
  final bool checked;
  final bool acting;
  final bool desktopActionsSupported;
  final VoidCallback onSelectionChanged;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final statusColor = taskStateColor(context, task.state);
    return Material(
      key: ValueKey('task-row-${task.id}'),
      color: selected || checked ? colors.surfaceSubtle : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final stacked = constraints.maxWidth < 520 || textScale >= 1.6;
              final details = _TaskRowDetails(
                task: task,
                statusColor: statusColor,
                checked: checked,
                onSelectionChanged: onSelectionChanged,
              );
              final action = _TaskRowAction(
                task: task,
                acting: acting,
                desktopActionsSupported: desktopActionsSupported,
                onPause: onPause,
                onResume: onResume,
                onOpenFile: onOpenFile,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TaskRowDetails extends StatelessWidget {
  const _TaskRowDetails({
    required this.task,
    required this.statusColor,
    required this.checked,
    required this.onSelectionChanged,
  });

  final DownloadTask task;
  final Color statusColor;
  final bool checked;
  final VoidCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final speedText = task.state == DownloadTaskState.downloading
        ? '${formatBytes(task.speedBps)}/s'
        : null;
    final progressText = task.total > 0
        ? '${(task.progress * 100).round()}%'
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: L10nKeys.tasksSelectAll.tr,
          child: Checkbox(
            key: ValueKey('select-task-${task.id}'),
            value: checked,
            onChanged: (_) => onSelectionChanged(),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
            border: Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: Icon(taskStateIcon(task.state), size: 15, color: statusColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      task.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (speedText != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      speedText,
                      key: ValueKey('task-speed-${task.id}'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 12,
                child: TransferTrack(
                  progress: task.progress,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    taskStateLabel(task.state),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    taskProgressText(task),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (progressText != null)
                    Text(
                      progressText,
                      key: ValueKey('task-progress-${task.id}'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRowAction extends StatelessWidget {
  const _TaskRowAction({
    required this.task,
    required this.acting,
    required this.desktopActionsSupported,
    required this.onPause,
    required this.onResume,
    required this.onOpenFile,
  });

  final DownloadTask task;
  final bool acting;
  final bool desktopActionsSupported;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    if (task.canPause) {
      return IconButton(
        key: ValueKey('pause-task-${task.id}'),
        tooltip: L10nKeys.taskPause.tr,
        onPressed: acting ? null : onPause,
        icon: const Icon(DownpeedIcons.pause),
      );
    }
    if (task.canResume) {
      return IconButton(
        key: ValueKey('resume-task-${task.id}'),
        tooltip: L10nKeys.taskResume.tr,
        onPressed: acting ? null : onResume,
        icon: const Icon(DownpeedIcons.resume),
      );
    }
    if (task.state == DownloadTaskState.completed && desktopActionsSupported) {
      return IconButton(
        key: ValueKey('open-task-${task.id}'),
        tooltip: L10nKeys.taskOpenFile.tr,
        onPressed: acting ? null : onOpenFile,
        icon: const Icon(DownpeedIcons.openFile),
      );
    }
    return Icon(
      DownpeedIcons.more,
      size: DownpeedThemeTokens.iconSize,
      color: context.downpeedColors.textMuted,
    );
  }
}

class _NoTaskSelection extends StatelessWidget {
  const _NoTaskSelection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DownpeedIcons.info, color: context.downpeedColors.textMuted),
            const SizedBox(height: 12),
            Text(
              L10nKeys.taskNoSelection.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              L10nKeys.taskNoSelectionBody.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.downpeedColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingTasks extends StatelessWidget {
  const _LoadingTasks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 220, child: TransferTrack(progress: 0.2)),
          const SizedBox(height: 16),
          Text(L10nKeys.tasksLoading.tr),
        ],
      ),
    );
  }
}

class _TaskLoadError extends StatelessWidget {
  const _TaskLoadError({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(DownpeedIcons.issues, size: 22),
            const SizedBox(height: 12),
            Text(L10nKeys.tasksLoadError.tr),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.retryTasks,
              icon: const Icon(DownpeedIcons.retry),
              label: Text(L10nKeys.engineRetry.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    final info = controller.engineService.info.value;
    final colors = context.downpeedColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DownpeedThemeTokens.pagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Column(
            children: [
              const DownpeedBrandMark(size: 32),
              const SizedBox(height: 20),
              Text(
                L10nKeys.tasksEmptyTitle.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(
                L10nKeys.tasksEmptyBody.tr,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: controller.openCreateDownload,
                    icon: const Icon(DownpeedIcons.add),
                    label: Text(L10nKeys.tasksAdd.tr),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.pasteDownload,
                    icon: const Icon(DownpeedIcons.paste),
                    label: Text(L10nKeys.tasksPaste.tr),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                info == null
                    ? L10nKeys.tasksEmptyHint.tr
                    : L10nKeys.engineVersion.trParams({
                        'version': info.version,
                      }),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DownpeedThemeTokens.pagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              const Icon(DownpeedIcons.engine, size: 24),
              const SizedBox(height: 18),
              Text(
                L10nKeys.engineOfflineTitle.tr,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                L10nKeys.engineOfflineBody.tr,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radius,
                  ),
                ),
                child: SelectableText(
                  'cd backend && go run ./cmd/downpeedd',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('retry-engine-button'),
                onPressed: controller.retryEngine,
                icon: const Icon(DownpeedIcons.retry),
                label: Text(L10nKeys.engineRetry.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckingState extends StatelessWidget {
  const _CheckingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 220, child: TransferTrack(progress: 0.18)),
          const SizedBox(height: 18),
          const EngineStatusBadge(),
        ],
      ),
    );
  }
}
