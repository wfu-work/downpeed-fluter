import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/batch_task_result.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/download_task.dart';
import '../../../services/embedded_engine_service.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/engine_status_badge.dart';
import '../../widgets/task_display.dart';
import '../../widgets/transfer_track.dart';
import '../task_detail/task_detail_view.dart';
import 'task_list_controller.dart';

const _taskPageMaxWidth = 1440.0;
const _taskCardBorderAlpha = 0.56;
const _taskDividerAlpha = 0.34;

class TaskListView extends GetView<TaskListController> {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentFilter = controller.filter.value;
      return DownpeedAppShell(
        selectedDestination: AppDestination.tasks,
        child: SafeArea(
          left: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskToolbar(controller: controller),
              _TaskFilterBar(
                controller: controller,
                selected: currentFilter,
                counts: TaskListFilter.values
                    .map(controller.countForFilter)
                    .toList(growable: false),
                onSelected: controller.setFilter,
              ),
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
      );
    });
  }
}

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({
    required this.controller,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final TaskListController controller;
  final TaskListFilter selected;
  final List<int> counts;
  final ValueChanged<TaskListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 720
        ? DownpeedThemeTokens.compactPagePadding
        : DownpeedThemeTokens.spaceXl;
    return Padding(
      key: const ValueKey('task-filter-bar'),
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _taskPageMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final filterControl = DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised.withValues(alpha: 0.78),
                  border: Border.all(
                    color: colors.border.withValues(
                      alpha: _taskCardBorderAlpha,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radiusLarge,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < TaskListFilter.values.length;
                        index++
                      ) ...[
                        _TaskFilterSegment(
                          value: TaskListFilter.values[index],
                          count: counts[index],
                          selected: selected == TaskListFilter.values[index],
                          onTap: () => onSelected(TaskListFilter.values[index]),
                        ),
                        if (index != TaskListFilter.values.length - 1)
                          const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
              );
              final search = _TaskSearchField(controller: controller);
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: filterControl,
                      ),
                    ),
                    const SizedBox(height: 8),
                    search,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: filterControl,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 240, child: search),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TaskFilterSegment extends StatelessWidget {
  const _TaskFilterSegment({
    required this.value,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final TaskListFilter value;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.sidebarSelection : Colors.transparent,
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        child: InkWell(
          key: ValueKey('task-filter-${value.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          hoverColor: colors.surfaceSubtle,
          focusColor: colors.surfaceSubtle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _filterIcon(value),
                    size: 14,
                    color: selected ? colors.text : colors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _filterLabel(value),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? colors.text : colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '$count',
                    key: ValueKey('task-filter-count-${value.name}'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? colors.textSecondary : colors.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _filterIcon(TaskListFilter filter) => switch (filter) {
    TaskListFilter.all => DownpeedIcons.all,
    TaskListFilter.active => DownpeedIcons.active,
    TaskListFilter.completed => DownpeedIcons.completed,
    TaskListFilter.issues => DownpeedIcons.issues,
  };

  String _filterLabel(TaskListFilter filter) => switch (filter) {
    TaskListFilter.all => L10nKeys.tasksFilterAll.tr,
    TaskListFilter.active => L10nKeys.tasksFilterActive.tr,
    TaskListFilter.completed => L10nKeys.tasksFilterCompleted.tr,
    TaskListFilter.issues => L10nKeys.tasksFilterIssues.tr,
  };
}

class _TaskToolbar extends StatelessWidget {
  const _TaskToolbar({required this.controller});

  final TaskListController controller;

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
        10,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _taskPageMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final title = Column(
                key: const ValueKey('task-toolbar-heading'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          L10nKeys.tasksTitle.tr,
                          key: const ValueKey('task-toolbar-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: DownpeedThemeTokens.textHeading,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          L10nKeys.tasksSubtitle.tr,
                          key: const ValueKey('task-toolbar-subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: DownpeedThemeTokens.textCaption,
                                color: colors.textMuted,
                              ),
                        ),
                      ),
                      const SizedBox(width: DownpeedThemeTokens.spaceSm),
                      const Opacity(
                        opacity: 0.72,
                        child: EngineStatusBadge(dense: true),
                      ),
                    ],
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TaskSortButton(controller: controller),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('add-download-button'),
                    tooltip: L10nKeys.tasksAdd.tr,
                    onPressed: controller.openCreateDownload,
                    icon: const Icon(DownpeedIcons.add),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
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
        ),
      ),
    );
  }
}

class _TaskSearchField extends StatelessWidget {
  const _TaskSearchField({required this.controller});

  final TaskListController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final fieldHeight = textScale >= 1.6
        ? 40.0
        : DownpeedThemeTokens.controlHeight;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      borderSide: BorderSide(
        color: colors.border.withValues(alpha: _taskCardBorderAlpha),
      ),
    );
    return SizedBox(
      height: fieldHeight,
      child: TextField(
        key: const ValueKey('task-search-field'),
        controller: controller.searchController,
        focusNode: controller.searchFocusNode,
        onChanged: controller.updateSearch,
        textInputAction: TextInputAction.search,
        cursorColor: colors.accent,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.text),
        decoration: InputDecoration(
          hintText: L10nKeys.tasksSearch.tr,
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          prefixIcon: const Icon(DownpeedIcons.search, size: 15),
          prefixIconColor: colors.textSecondary,
          prefixIconConstraints: BoxConstraints.tightFor(
            width: fieldHeight,
            height: fieldHeight,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          fillColor: colors.surfaceRaised,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: colors.borderStrong.withValues(alpha: 0.9),
              width: 1.25,
            ),
          ),
        ),
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
      icon: const Icon(DownpeedIcons.sort, size: 17),
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
          if (!showInspector || selected == null) return list;
          final inspectorWidth = (constraints.maxWidth * 0.36)
              .clamp(360.0, 420.0)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: list),
              Container(
                key: const ValueKey('task-inspector'),
                width: inspectorWidth,
                decoration: BoxDecoration(
                  color: context.downpeedColors.surfaceRaised.withValues(
                    alpha: 0.72,
                  ),
                  border: Border(
                    left: BorderSide(
                      color: context.downpeedColors.border.withValues(
                        alpha: _taskDividerAlpha,
                      ),
                    ),
                  ),
                ),
                child: TaskDetailPanel(
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
                  diagnosticsService: controller.btDiagnostics,
                  diagnosticsExpanded: controller.diagnosticsExpandedTaskIds
                      .contains(selected.id),
                  onToggleDiagnostics: () =>
                      controller.toggleDiagnostics(selected.id),
                  onClose: controller.closeInspector,
                  onPause: () => controller.pauseTask(selected),
                  onResume: () => controller.resumeTask(selected),
                  onRetry: () => controller.retryTask(selected),
                  onCancel: () => controller.cancelTask(selected),
                  onDelete: () => controller.deleteTask(selected),
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
    final colors = context.downpeedColors;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 720
        ? DownpeedThemeTokens.compactPagePadding
        : DownpeedThemeTokens.spaceXl;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > _taskPageMaxWidth
              ? _taskPageMaxWidth
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised.withValues(alpha: 0.24),
                  border: Border.all(
                    color: colors.border.withValues(
                      alpha: _taskCardBorderAlpha,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radiusLarge,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.hasSelection)
                      _BatchCommandStrip(controller: controller)
                    else
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle.withValues(alpha: 0.36),
                          border: Border(
                            bottom: BorderSide(
                              color: colors.border.withValues(
                                alpha: _taskDividerAlpha,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                L10nKeys.tasksCount.trParams({
                                  'count': '${tasks.length}',
                                }),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.textMuted),
                              ),
                            ),
                            if (controller.filter.value ==
                                    TaskListFilter.completed &&
                                controller.completedTaskCount > 0)
                              TextButton.icon(
                                key: const ValueKey('clear-completed-button'),
                                onPressed: controller.clearCompleted,
                                icon: const Icon(DownpeedIcons.delete),
                                label: Text(L10nKeys.tasksClearCompleted.tr),
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
                          horizontal: 16,
                          vertical: 9,
                        ),
                        color: colors.surfaceSubtle.withValues(alpha: 0.32),
                        child: Text(
                          batchMessage,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    if (fileActionError != null)
                      Container(
                        key: const ValueKey('file-action-message'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        color: colors.danger.withValues(alpha: 0.07),
                        child: Text(
                          fileActionError,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.danger),
                        ),
                      ),
                    Expanded(
                      child: DecoratedBox(
                        key: const ValueKey('task-list-surface'),
                        decoration: context.downpeedTaskListDecoration,
                        child: tasks.isEmpty
                            ? const _NoMatchingTasks()
                            : RefreshIndicator(
                                onRefresh: controller.retryTasks,
                                child: ListView.builder(
                                  key: const ValueKey('task-list'),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    22,
                                  ),
                                  itemCount: tasks.length,
                                  itemBuilder: (context, index) {
                                    final task = tasks[index];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: index == tasks.length - 1
                                            ? 0
                                            : 8,
                                      ),
                                      child: _TaskRow(
                                        task: task,
                                        selected:
                                            controller.selectedTaskId.value ==
                                            task.id,
                                        checked: controller.selectedTaskIds
                                            .contains(task.id),
                                        acting:
                                            controller.taskService.isActing(
                                              task.id,
                                            ) ||
                                            controller.desktopActions.isActing(
                                              task.id,
                                            ),
                                        desktopActionsSupported: controller
                                            .desktopActions
                                            .isSupported,
                                        onSelectionChanged: () => controller
                                            .toggleTaskSelection(task.id),
                                        onTap: () => controller.openTask(
                                          task,
                                          compact: navigateToDetail,
                                        ),
                                        onPause: () =>
                                            controller.pauseTask(task),
                                        onResume: () =>
                                            controller.resumeTask(task),
                                        onRetry: () =>
                                            controller.retryTask(task),
                                        onCancel: () =>
                                            controller.cancelTask(task),
                                        onOpenFile: () =>
                                            controller.openFile(task),
                                        onRevealFile: () =>
                                            controller.revealFile(task),
                                        onDelete: () =>
                                            controller.deleteTask(task),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.fromLTRB(32, 6, 16, 6),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.42),
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: _taskDividerAlpha),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Checkbox(
            key: const ValueKey('select-all-visible'),
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
          TextButton.icon(
            key: const ValueKey('batch-delete-button'),
            onPressed: controller.canDeleteSelection
                ? controller.deleteSelected
                : null,
            icon: Icon(
              DownpeedIcons.delete,
              color: controller.canDeleteSelection ? colors.danger : null,
            ),
            label: Text(
              L10nKeys.tasksDeleteSelected.tr,
              style: TextStyle(
                color: controller.canDeleteSelection ? colors.danger : null,
              ),
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
    required this.onRetry,
    required this.onCancel,
    required this.onOpenFile,
    required this.onRevealFile,
    required this.onDelete,
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
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onOpenFile;
  final VoidCallback onRevealFile;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final statusColor = taskStateColor(context, task.state);
    final rowColor = selected || checked
        ? colors.taskRowSelected
        : colors.taskRow;
    final rowShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DownpeedThemeTokens.taskRowRadius),
      side: BorderSide(
        color: selected || checked
            ? colors.accent.withValues(alpha: 0.34)
            : colors.taskRowBorder.withValues(alpha: _taskCardBorderAlpha),
      ),
    );
    return Material(
      key: ValueKey('task-row-${task.id}'),
      color: rowColor,
      shape: rowShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.taskRowRadius),
        hoverColor: colors.taskRowHover,
        focusColor: colors.taskRowHover.withValues(alpha: 0.88),
        splashColor: colors.sidebarSelection.withValues(alpha: 0.36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final compact = constraints.maxWidth < 560 || textScale >= 1.6;
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
                onRetry: onRetry,
                onOpenFile: onOpenFile,
              );
              return Row(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
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

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    final hasTaskActions =
        task.canPause ||
        task.canResume ||
        task.canRetry ||
        task.canCancel ||
        (task.state == DownloadTaskState.completed && desktopActionsSupported);
    final actions = <PopupMenuEntry<_TaskContextAction>>[
      _TaskContextMenuItem(
        key: ValueKey('context-details-${task.id}'),
        value: _TaskContextAction.details,
        icon: DownpeedIcons.info,
        label: L10nKeys.taskDetails.tr,
      ),
      if (hasTaskActions) const PopupMenuDivider(height: 9),
      if (task.canPause)
        _TaskContextMenuItem(
          key: ValueKey('context-pause-${task.id}'),
          value: _TaskContextAction.pause,
          icon: DownpeedIcons.pause,
          label: L10nKeys.taskPause.tr,
          enabled: !acting,
        ),
      if (task.canResume)
        _TaskContextMenuItem(
          key: ValueKey('context-resume-${task.id}'),
          value: _TaskContextAction.resume,
          icon: DownpeedIcons.resume,
          label: L10nKeys.taskResume.tr,
          enabled: !acting,
        ),
      if (task.canRetry)
        _TaskContextMenuItem(
          key: ValueKey('context-retry-${task.id}'),
          value: _TaskContextAction.retry,
          icon: DownpeedIcons.retry,
          label: L10nKeys.taskRetry.tr,
          enabled: !acting,
        ),
      if (task.canCancel)
        _TaskContextMenuItem(
          key: ValueKey('context-cancel-${task.id}'),
          value: _TaskContextAction.cancel,
          icon: DownpeedIcons.stop,
          label: L10nKeys.taskCancel.tr,
          enabled: !acting,
          destructive: true,
        ),
      if (task.state == DownloadTaskState.completed &&
          desktopActionsSupported) ...[
        _TaskContextMenuItem(
          key: ValueKey('context-open-file-${task.id}'),
          value: _TaskContextAction.openFile,
          icon: DownpeedIcons.openFile,
          label: L10nKeys.taskOpenFile.tr,
          enabled: !acting,
        ),
        _TaskContextMenuItem(
          key: ValueKey('context-reveal-file-${task.id}'),
          value: _TaskContextAction.revealFile,
          icon: DownpeedIcons.revealFile,
          label: L10nKeys.taskRevealFile.tr,
          enabled: !acting,
        ),
      ],
      if (task.isTerminal) ...[
        const PopupMenuDivider(height: 9),
        _TaskContextMenuItem(
          key: ValueKey('context-delete-${task.id}'),
          value: _TaskContextAction.delete,
          icon: DownpeedIcons.delete,
          label: L10nKeys.taskDelete.tr,
          enabled: !acting,
          destructive: true,
        ),
      ],
    ];
    final action = await showMenu<_TaskContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      constraints: const BoxConstraints(minWidth: 208, maxWidth: 256),
      items: actions,
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TaskContextAction.details:
        onTap();
      case _TaskContextAction.pause:
        onPause();
      case _TaskContextAction.resume:
        onResume();
      case _TaskContextAction.retry:
        onRetry();
      case _TaskContextAction.cancel:
        onCancel();
      case _TaskContextAction.openFile:
        onOpenFile();
      case _TaskContextAction.revealFile:
        onRevealFile();
      case _TaskContextAction.delete:
        onDelete();
    }
  }
}

enum _TaskContextAction {
  details,
  pause,
  resume,
  retry,
  cancel,
  openFile,
  revealFile,
  delete,
}

class _TaskContextMenuItem extends PopupMenuItem<_TaskContextAction> {
  _TaskContextMenuItem({
    super.key,
    required _TaskContextAction value,
    required IconData icon,
    required String label,
    super.enabled = true,
    bool destructive = false,
  }) : super(
         value: value,
         height: 36,
         child: Builder(
           builder: (context) {
             final color = !enabled
                 ? context.downpeedColors.textMuted
                 : destructive
                 ? context.downpeedColors.danger
                 : context.downpeedColors.text;
             return Row(
               children: [
                 Icon(icon, size: 15, color: color),
                 const SizedBox(width: 10),
                 Expanded(
                   child: Text(
                     label,
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: Theme.of(
                       context,
                     ).textTheme.bodyMedium?.copyWith(color: color),
                   ),
                 ),
               ],
             );
           },
         ),
       );
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
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final speedText = task.state == DownloadTaskState.downloading
        ? '${formatBytes(task.speedBps)}/s'
        : null;
    final progressText = task.total > 0
        ? '${(task.progress * 100).round()}%'
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 530 || textScale >= 1.6;
        return Row(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: compact ? 1 : 0),
              child: Tooltip(
                message: L10nKeys.tasksSelectAll.tr,
                child: Checkbox(
                  key: ValueKey('select-task-${task.id}'),
                  value: checked,
                  onChanged: (_) => onSelectionChanged(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(top: compact ? 4 : 0),
              child: SizedBox.square(
                dimension: 24,
                child: Center(
                  child: Icon(
                    taskStateIcon(task.state),
                    key: ValueKey('task-state-icon-${task.id}'),
                    size: DownpeedThemeTokens.taskStatusIconSize,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TaskRowContent(
                task: task,
                statusColor: statusColor,
                progressText: progressText,
                speedText: speedText,
                compact: compact,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskRowContent extends StatelessWidget {
  const _TaskRowContent({
    required this.task,
    required this.statusColor,
    required this.progressText,
    required this.speedText,
    required this.compact,
  });

  final DownloadTask task;
  final Color statusColor;
  final String? progressText;
  final String? speedText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('task-content-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.fileName,
          key: ValueKey('task-identity-${task.id}'),
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: DownpeedThemeTokens.textBodyLarge,
            fontWeight: FontWeight.w600,
            color: context.downpeedColors.text,
            height: 1.22,
          ),
        ),
        if (task.hasFutureSchedule) ...[
          const SizedBox(height: 3),
          Text(
            L10nKeys.taskScheduledLabel.trParams({
              'time': DateFormat(
                'MM-dd HH:mm',
              ).format(task.scheduledAt!.toLocal()),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.downpeedColors.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        SizedBox(height: compact ? 8 : 7),
        if (compact)
          _CompactTaskTransfer(
            task: task,
            statusColor: statusColor,
            progressText: progressText,
            speedText: speedText,
          )
        else
          _WideTaskTransfer(
            task: task,
            statusColor: statusColor,
            progressText: progressText,
            speedText: speedText,
          ),
      ],
    );
  }
}

class _WideTaskTransfer extends StatelessWidget {
  const _WideTaskTransfer({
    required this.task,
    required this.statusColor,
    required this.progressText,
    required this.speedText,
  });

  final DownloadTask task;
  final Color statusColor;
  final String? progressText;
  final String? speedText;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Row(
      key: ValueKey('task-transfer-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            taskStateLabel(task.state),
            key: ValueKey('task-state-${task.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              key: ValueKey('task-track-${task.id}'),
              width: double.infinity,
              height: 14,
              child: TransferTrack(progress: task.progress, color: statusColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: Text(
            taskProgressText(task),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: speedText == null
              ? null
              : Text(
                  speedText!,
                  key: ValueKey('task-speed-${task.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: progressText == null
              ? null
              : Text(
                  progressText!,
                  key: ValueKey('task-progress-${task.id}'),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CompactTaskTransfer extends StatelessWidget {
  const _CompactTaskTransfer({
    required this.task,
    required this.statusColor,
    required this.progressText,
    required this.speedText,
  });

  final DownloadTask task;
  final Color statusColor;
  final String? progressText;
  final String? speedText;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Column(
      key: ValueKey('task-transfer-${task.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                taskStateLabel(task.state),
                key: ValueKey('task-state-${task.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (progressText != null)
              Text(
                progressText!,
                key: ValueKey('task-progress-${task.id}'),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          key: ValueKey('task-track-${task.id}'),
          height: 12,
          child: TransferTrack(progress: task.progress, color: statusColor),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                taskProgressText(task),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (speedText != null) ...[
              const SizedBox(width: 10),
              Text(
                speedText!,
                key: ValueKey('task-speed-${task.id}'),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
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
    required this.onRetry,
    required this.onOpenFile,
  });

  final DownloadTask task;
  final bool acting;
  final bool desktopActionsSupported;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
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
    if (task.canRetry) {
      return IconButton(
        key: ValueKey('retry-task-${task.id}'),
        tooltip: L10nKeys.taskRetry.tr,
        onPressed: acting ? null : onRetry,
        icon: const Icon(DownpeedIcons.retry),
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
    final errorMessage = controller.engineService.errorMessage.value;
    final hasEmbeddedError =
        Get.isRegistered<EmbeddedEngineService>() &&
        EmbeddedEngineService.to.errorMessage.value != null;
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
                errorMessage ?? L10nKeys.engineOfflineBody.tr,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
              if (!hasEmbeddedError) ...[
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
              ],
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
