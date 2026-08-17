import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/build_info.dart';
import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/engine_diagnostics.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/engine_settings.dart';
import '../../../services/preferences_service.dart';
import '../../../services/startup_service.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/downpeed_controls.dart';
import '../../widgets/engine_status_badge.dart';
import '../../widgets/task_display.dart';
import 'settings_controller.dart';

const _settingsWideBreakpoint = 700.0;
const _settingsNavigationWidth = 214.0;
const _settingsContentMaxWidth = 760.0;
const _macOSTitleBarHeight = 38.0;
const _settingsCardBorderAlpha = 0.56;
const _settingsDividerAlpha = 0.34;

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _settingsWideBreakpoint) {
          return _WideSettingsLayout(controller: controller);
        }
        return _CompactSettingsLayout(controller: controller);
      },
    );
  }
}

class _WideSettingsLayout extends StatelessWidget {
  const _WideSettingsLayout({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('settings-page'),
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: context.downpeedWorkspaceDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _settingsNavigationWidth,
              child: _SettingsNavigation(controller: controller),
            ),
            Expanded(
              child: Obx(
                () => _SettingsContent(
                  controller: controller,
                  section: controller.selectedSection.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSettingsLayout extends StatelessWidget {
  const _CompactSettingsLayout({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showDetail = controller.compactDetailVisible.value;
      final section = controller.selectedSection.value;
      return Scaffold(
        key: const ValueKey('settings-page'),
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: context.downpeedWorkspaceDecoration,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactSettingsHeader(
                  title: showDetail
                      ? _settingsSectionTitle(section)
                      : L10nKeys.settingsTitle.tr,
                  tooltip: showDetail
                      ? L10nKeys.settingsBackToMenu.tr
                      : L10nKeys.settingsBackToTasks.tr,
                  onBack: showDetail
                      ? controller.closeCompactDetail
                      : controller.backToTasks,
                ),
                Expanded(
                  child: showDetail
                      ? _SettingsContent(
                          controller: controller,
                          section: section,
                          compact: true,
                        )
                      : _SettingsNavigation(
                          controller: controller,
                          compact: true,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CompactSettingsHeader extends StatelessWidget {
  const _CompactSettingsHeader({
    required this.title,
    required this.tooltip,
    required this.onBack,
  });

  final String title;
  final String tooltip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DownpeedThemeTokens.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.downpeedColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('settings-compact-back'),
            tooltip: tooltip,
            onPressed: onBack,
            icon: const Icon(DownpeedIcons.back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({required this.controller, this.compact = false});

  final SettingsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return DecoratedBox(
      key: const ValueKey('settings-navigation'),
      decoration:
          (compact
                  ? const BoxDecoration(color: Colors.transparent)
                  : context.downpeedSidebarDecoration)
              .copyWith(
                border: compact
                    ? null
                    : Border(right: BorderSide(color: colors.border)),
              ),
      child: SafeArea(
        top: compact || defaultTargetPlatform != TargetPlatform.macOS,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              if (defaultTargetPlatform == TargetPlatform.macOS)
                const SizedBox(height: _macOSTitleBarHeight),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('settings-back-to-tasks'),
                    onPressed: controller.backToTasks,
                    icon: const Icon(DownpeedIcons.back),
                    label: Text(L10nKeys.settingsBackToTasks.tr),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nKeys.settingsTitle.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      L10nKeys.settingsSubtitle.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                child: Text(
                  L10nKeys.settingsSubtitle.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            Expanded(
              child: Obx(
                () => _SettingsNavigationList(
                  controller: controller,
                  compact: compact,
                  selected: controller.selectedSection.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsNavigationList extends StatelessWidget {
  const _SettingsNavigationList({
    required this.controller,
    required this.compact,
    required this.selected,
  });

  final SettingsController controller;
  final bool compact;
  final SettingsSection selected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 8, 2, compact ? 12 : 8, 28),
      children: [
        for (final group in _settingsNavigationGroups()) ...[
          _NavigationGroupLabel(label: group.label),
          for (final destination in group.destinations)
            _SettingsNavigationTile(
              destination: destination,
              selected: selected == destination.section,
              compact: compact,
              onTap: () => controller.selectSection(
                destination.section,
                compact: compact,
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NavigationGroupLabel extends StatelessWidget {
  const _NavigationGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.downpeedColors.textMuted,
        ),
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _SettingsNavigationDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? compact
                  ? colors.surfaceSubtle
                  : colors.sidebarSelection
            : Colors.transparent,
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        child: InkWell(
          key: destination.key,
          onTap: onTap,
          hoverColor: compact ? colors.surfaceSubtle : colors.sidebarSelection,
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          child: SizedBox(
            height: compact ? 44 : 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    size: DownpeedThemeTokens.iconSize,
                    color: selected ? colors.text : colors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (compact)
                    Icon(DownpeedIcons.more, size: 14, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({
    required this.controller,
    required this.section,
    this.compact = false,
  });

  final SettingsController controller;
  final SettingsSection section;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locale = controller.appService.locale.value.languageCode;
      final engineState = controller.engineService.state.value;
      final engineInfo = controller.engineService.info.value;
      final scheduler = controller.engineSettingsService.scheduler;
      final schedulerSaving = controller.engineSettingsService.isSaving.value;
      final fileConflictPolicy =
          controller.engineSettingsService.fileConflictPolicy;
      final diagnostics = controller.diagnosticsService.diagnostics.value;
      final diagnosticsLoading = controller.diagnosticsService.isLoading.value;
      final diagnosticsExporting =
          controller.diagnosticsService.isExporting.value;
      return ColoredBox(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _settingsContentMaxWidth,
            ),
            child: ListView(
              key: ValueKey('settings-content-${section.name}'),
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                compact ? 24 : 52,
                compact ? 18 : 32,
                40,
              ),
              children: [
                Text(
                  _settingsSectionTitle(section),
                  key: const ValueKey('settings-content-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  _settingsSectionDescription(section),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.downpeedColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsGroup(
                  children: switch (section) {
                    SettingsSection.appearance => [
                      _SettingsRow(
                        icon: DownpeedIcons.systemTheme,
                        title: L10nKeys.settingsTheme.tr,
                        description: L10nKeys.settingsThemeDescription.tr,
                        control: DownpeedSegmentedControl<ThemeMode>(
                          key: const ValueKey('settings-theme-control'),
                          segments: [
                            DownpeedSegment(
                              value: ThemeMode.system,
                              icon: DownpeedIcons.systemTheme,
                              label: L10nKeys.settingsThemeSystem.tr,
                            ),
                            DownpeedSegment(
                              value: ThemeMode.light,
                              icon: DownpeedIcons.lightTheme,
                              label: L10nKeys.settingsThemeLight.tr,
                            ),
                            DownpeedSegment(
                              value: ThemeMode.dark,
                              icon: DownpeedIcons.darkTheme,
                              label: L10nKeys.settingsThemeDark.tr,
                            ),
                          ],
                          selected: controller.appService.themeMode.value,
                          onSelected: (value) =>
                              controller.selectTheme(<ThemeMode>{value}),
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.language,
                        title: L10nKeys.settingsLanguage.tr,
                        description: L10nKeys.settingsLanguageDescription.tr,
                        control: DownpeedSegmentedControl<String>(
                          key: const ValueKey('settings-language-control'),
                          segments: [
                            DownpeedSegment(
                              value: 'zh',
                              label: L10nKeys.settingsLanguageChinese.tr,
                            ),
                            DownpeedSegment(
                              value: 'en',
                              label: L10nKeys.settingsLanguageEnglish.tr,
                            ),
                          ],
                          selected: locale == 'en' ? 'en' : 'zh',
                          onSelected: (value) =>
                              controller.selectLanguage(<String>{value}),
                        ),
                      ),
                    ],
                    SettingsSection.workspace => [
                      _SettingsRow(
                        icon: DownpeedIcons.layout,
                        title: L10nKeys.settingsSidebarExpanded.tr,
                        description:
                            L10nKeys.settingsSidebarExpandedDescription.tr,
                        control: DownpeedSwitch(
                          key: const ValueKey('settings-sidebar-expanded'),
                          value: controller.preferences.sidebarExpanded.value,
                          onChanged: controller.setSidebarExpanded,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.sidebarOpen,
                        title: L10nKeys.settingsSidebarWidth.tr,
                        description:
                            L10nKeys.settingsSidebarWidthDescription.tr,
                        control: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${controller.preferences.sidebarWidth.value.round()} px',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: context.downpeedColors.textSecondary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            const SizedBox(width: DownpeedThemeTokens.spaceSm),
                            TextButton(
                              key: const ValueKey('settings-sidebar-reset'),
                              onPressed: controller.resetSidebarWidth,
                              child: Text(L10nKeys.settingsReset.tr),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SettingsSection.notifications => [
                      _SettingsRow(
                        icon: DownpeedIcons.notifications,
                        title: L10nKeys.settingsCompletionNotifications.tr,
                        description: L10nKeys
                            .settingsCompletionNotificationsDescription
                            .tr,
                        control: DownpeedSwitch(
                          key: const ValueKey(
                            'settings-completion-notifications',
                          ),
                          value: controller
                              .preferences
                              .completionNotificationsEnabled
                              .value,
                          onChanged:
                              controller.setCompletionNotificationsEnabled,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.keyboard,
                        title: L10nKeys.settingsNewDownloadShortcut.tr,
                        description:
                            L10nKeys.settingsNewDownloadShortcutDescription.tr,
                        control: _SettingsValue(
                          key: const ValueKey('settings-new-download-shortcut'),
                          value: defaultTargetPlatform == TargetPlatform.macOS
                              ? '⌘ N'
                              : 'Ctrl N',
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.tray,
                        title: L10nKeys.settingsCloseToTray.tr,
                        description: L10nKeys.settingsCloseToTrayDescription.tr,
                        control: DownpeedSwitch(
                          key: const ValueKey('settings-close-to-tray'),
                          value:
                              controller.preferences.closeToTrayEnabled.value,
                          onChanged: controller.setCloseToTrayEnabled,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.startup,
                        title: L10nKeys.settingsLaunchAtLogin.tr,
                        description:
                            L10nKeys.settingsLaunchAtLoginDescription.tr,
                        control: DownpeedSwitch(
                          key: const ValueKey('settings-launch-at-login'),
                          value: controller.startupService.enabled.value,
                          onChanged:
                              controller.startupService.supported.value &&
                                  !controller.startupService.isLoading.value
                              ? controller.setLaunchAtLogin
                              : null,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.tray,
                        title: L10nKeys.settingsStartHiddenOnLogin.tr,
                        description:
                            L10nKeys.settingsStartHiddenOnLoginDescription.tr,
                        control: DownpeedSwitch(
                          key: const ValueKey('settings-start-hidden-on-login'),
                          value:
                              controller.preferences.startHiddenOnLogin.value,
                          onChanged:
                              controller.startupService.supported.value &&
                                  controller.startupService.enabled.value &&
                                  !controller.startupService.isLoading.value
                              ? controller.setStartHiddenOnLogin
                              : null,
                        ),
                      ),
                    ],
                    SettingsSection.downloads => [
                      _SettingsRow(
                        icon: DownpeedIcons.folder,
                        title: L10nKeys.settingsDownloadDirectory.tr,
                        description:
                            L10nKeys.settingsDownloadDirectoryDescription.tr,
                        control: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _SettingsValue(
                                key: const ValueKey(
                                  'settings-default-download-directory',
                                ),
                                value:
                                    controller
                                        .engineSettingsService
                                        .defaultDownloadDirectory ??
                                    (controller
                                            .engineSettingsService
                                            .isLoading
                                            .value
                                        ? L10nKeys
                                              .settingsDownloadDirectoryLoading
                                              .tr
                                        : L10nKeys
                                              .settingsDownloadDirectoryUnavailable
                                              .tr),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'settings-choose-download-directory',
                                ),
                                onPressed:
                                    controller
                                                .engineSettingsService
                                                .defaultDownloadDirectory ==
                                            null ||
                                        controller
                                            .isPickingDownloadDirectory
                                            .value ||
                                        controller
                                            .engineSettingsService
                                            .isSaving
                                            .value
                                    ? null
                                    : controller.chooseDefaultDownloadDirectory,
                                icon: const Icon(DownpeedIcons.folder),
                                label: Text(
                                  controller
                                          .engineSettingsService
                                          .isSavingDefaultDownloadDirectory
                                          .value
                                      ? L10nKeys
                                            .settingsDownloadDirectorySaving
                                            .tr
                                      : L10nKeys
                                            .settingsDownloadDirectoryChange
                                            .tr,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.file,
                        title: L10nKeys.settingsFileConflictPolicy.tr,
                        description:
                            L10nKeys.settingsFileConflictPolicyDescription.tr,
                        control: fileConflictPolicy == null
                            ? _SettingsValue(
                                key: const ValueKey(
                                  'settings-file-conflict-loading',
                                ),
                                value:
                                    controller
                                        .engineSettingsService
                                        .isLoading
                                        .value
                                    ? L10nKeys
                                          .settingsDownloadDirectoryLoading
                                          .tr
                                    : L10nKeys
                                          .settingsDownloadDirectoryUnavailable
                                          .tr,
                              )
                            : compact &&
                                  MediaQuery.textScalerOf(context).scale(14) >=
                                      21
                            ? DownpeedMenuControl<FileConflictPolicy>(
                                key: const ValueKey(
                                  'settings-file-conflict-policy',
                                ),
                                value: fileConflictPolicy,
                                options: [
                                  DownpeedMenuOption(
                                    value: FileConflictPolicy.uniquify,
                                    label: L10nKeys
                                        .settingsFileConflictPolicyRename
                                        .tr,
                                  ),
                                  DownpeedMenuOption(
                                    value: FileConflictPolicy.fail,
                                    label: L10nKeys
                                        .settingsFileConflictPolicyStop
                                        .tr,
                                  ),
                                ],
                                onSelected: schedulerSaving
                                    ? null
                                    : controller.setFileConflictPolicy,
                                tooltip: L10nKeys.settingsFileConflictPolicy.tr,
                              )
                            : DownpeedSegmentedControl<FileConflictPolicy>(
                                key: const ValueKey(
                                  'settings-file-conflict-policy',
                                ),
                                segments: [
                                  DownpeedSegment(
                                    value: FileConflictPolicy.uniquify,
                                    icon: DownpeedIcons.file,
                                    label: L10nKeys
                                        .settingsFileConflictPolicyRename
                                        .tr,
                                  ),
                                  DownpeedSegment(
                                    value: FileConflictPolicy.fail,
                                    icon: DownpeedIcons.stop,
                                    label: L10nKeys
                                        .settingsFileConflictPolicyStop
                                        .tr,
                                  ),
                                ],
                                selected: fileConflictPolicy,
                                onSelected: schedulerSaving
                                    ? null
                                    : controller.setFileConflictPolicy,
                              ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.completed,
                        title: L10nKeys.settingsDownloadCompletionAction.tr,
                        description: L10nKeys
                            .settingsDownloadCompletionActionDescription
                            .tr,
                        control:
                            compact &&
                                MediaQuery.textScalerOf(context).scale(14) >= 21
                            ? DownpeedMenuControl<DownloadCompletionAction>(
                                key: const ValueKey(
                                  'settings-download-completion-action',
                                ),
                                value: controller
                                    .preferences
                                    .downloadCompletionAction
                                    .value,
                                options: [
                                  DownpeedMenuOption(
                                    value: DownloadCompletionAction.none,
                                    label: L10nKeys
                                        .settingsDownloadCompletionActionNone
                                        .tr,
                                  ),
                                  DownpeedMenuOption(
                                    value: DownloadCompletionAction.revealFile,
                                    label: L10nKeys
                                        .settingsDownloadCompletionActionReveal
                                        .tr,
                                  ),
                                ],
                                onSelected:
                                    controller.setDownloadCompletionAction,
                                tooltip: L10nKeys
                                    .settingsDownloadCompletionAction
                                    .tr,
                              )
                            : DownpeedSegmentedControl<
                                DownloadCompletionAction
                              >(
                                key: const ValueKey(
                                  'settings-download-completion-action',
                                ),
                                segments: [
                                  DownpeedSegment(
                                    value: DownloadCompletionAction.none,
                                    icon: DownpeedIcons.minus,
                                    label: L10nKeys
                                        .settingsDownloadCompletionActionNone
                                        .tr,
                                  ),
                                  DownpeedSegment(
                                    value: DownloadCompletionAction.revealFile,
                                    icon: DownpeedIcons.revealFile,
                                    label: L10nKeys
                                        .settingsDownloadCompletionActionReveal
                                        .tr,
                                  ),
                                ],
                                selected: controller
                                    .preferences
                                    .downloadCompletionAction
                                    .value,
                                onSelected:
                                    controller.setDownloadCompletionAction,
                              ),
                      ),
                    ],
                    SettingsSection.scheduler => [
                      _SettingsRow(
                        icon: DownpeedIcons.scheduler,
                        title: L10nKeys.settingsSchedulerMaxConcurrentTasks.tr,
                        description: L10nKeys
                            .settingsSchedulerMaxConcurrentTasksDescription
                            .tr,
                        control: scheduler == null
                            ? _SettingsValue(
                                key: const ValueKey(
                                  'settings-scheduler-concurrency-loading',
                                ),
                                value:
                                    controller
                                        .engineSettingsService
                                        .isLoading
                                        .value
                                    ? L10nKeys
                                          .settingsDownloadDirectoryLoading
                                          .tr
                                    : L10nKeys
                                          .settingsDownloadDirectoryUnavailable
                                          .tr,
                              )
                            : DownpeedNumberStepper(
                                key: const ValueKey(
                                  'settings-scheduler-concurrency',
                                ),
                                decrementKey: const ValueKey(
                                  'settings-scheduler-concurrency-decrement',
                                ),
                                incrementKey: const ValueKey(
                                  'settings-scheduler-concurrency-increment',
                                ),
                                value: scheduler.maxConcurrentTasks,
                                minimum:
                                    SchedulerSettings.minimumConcurrentTasks,
                                maximum:
                                    SchedulerSettings.maximumConcurrentTasks,
                                onChanged: schedulerSaving
                                    ? null
                                    : controller.setMaxConcurrentTasks,
                                decrementTooltip: L10nKeys
                                    .settingsSchedulerDecreaseConcurrency
                                    .tr,
                                incrementTooltip: L10nKeys
                                    .settingsSchedulerIncreaseConcurrency
                                    .tr,
                              ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.speedLimit,
                        title: L10nKeys.settingsSchedulerDownloadRateLimit.tr,
                        description: L10nKeys
                            .settingsSchedulerDownloadRateLimitDescription
                            .tr,
                        control: scheduler == null
                            ? _SettingsValue(
                                key: const ValueKey(
                                  'settings-scheduler-rate-loading',
                                ),
                                value:
                                    controller
                                        .engineSettingsService
                                        .isLoading
                                        .value
                                    ? L10nKeys
                                          .settingsDownloadDirectoryLoading
                                          .tr
                                    : L10nKeys
                                          .settingsDownloadDirectoryUnavailable
                                          .tr,
                              )
                            : DownpeedMenuControl<int>(
                                key: const ValueKey(
                                  'settings-scheduler-rate-limit',
                                ),
                                value: scheduler.downloadRateLimit,
                                options: [
                                  for (final value in _schedulerRateLimits(
                                    scheduler.downloadRateLimit,
                                  ))
                                    DownpeedMenuOption<int>(
                                      value: value,
                                      label: _schedulerRateLabel(value),
                                    ),
                                ],
                                onSelected: schedulerSaving
                                    ? null
                                    : controller.setDownloadRateLimit,
                                tooltip: L10nKeys.settingsSchedulerRateMenu.tr,
                              ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.retryPolicy,
                        title: L10nKeys.settingsSchedulerAutomaticRetries.tr,
                        description: L10nKeys
                            .settingsSchedulerAutomaticRetriesDescription
                            .tr,
                        control: scheduler == null
                            ? _SettingsValue(
                                key: const ValueKey(
                                  'settings-scheduler-retries-loading',
                                ),
                                value:
                                    controller
                                        .engineSettingsService
                                        .isLoading
                                        .value
                                    ? L10nKeys
                                          .settingsDownloadDirectoryLoading
                                          .tr
                                    : L10nKeys
                                          .settingsDownloadDirectoryUnavailable
                                          .tr,
                              )
                            : DownpeedNumberStepper(
                                key: const ValueKey(
                                  'settings-scheduler-retries',
                                ),
                                decrementKey: const ValueKey(
                                  'settings-scheduler-retries-decrement',
                                ),
                                incrementKey: const ValueKey(
                                  'settings-scheduler-retries-increment',
                                ),
                                value: scheduler.maxRetries,
                                minimum: SchedulerSettings.minimumRetries,
                                maximum: SchedulerSettings.maximumRetries,
                                onChanged: schedulerSaving
                                    ? null
                                    : controller.setMaxRetries,
                                decrementTooltip: L10nKeys
                                    .settingsSchedulerDecreaseRetries
                                    .tr,
                                incrementTooltip: L10nKeys
                                    .settingsSchedulerIncreaseRetries
                                    .tr,
                              ),
                      ),
                    ],
                    SettingsSection.bitTorrent => [
                      _SettingsRow(
                        icon: DownpeedIcons.connections,
                        title: L10nKeys.settingsBTPeerBudget.tr,
                        description:
                            L10nKeys.settingsBTPeerBudgetDescription.tr,
                        control:
                            controller.engineSettingsService.bitTorrent == null
                            ? _SettingsValue(
                                key: const ValueKey(
                                  'settings-bt-peer-budget-loading',
                                ),
                                value: L10nKeys
                                    .settingsDownloadDirectoryLoading
                                    .tr,
                              )
                            : DownpeedSegmentedControl<int>(
                                key: const ValueKey('settings-bt-peer-budget'),
                                segments: [
                                  for (final count in <int>{
                                    12,
                                    24,
                                    40,
                                    80,
                                    controller
                                        .engineSettingsService
                                        .bitTorrent!
                                        .maxPeerConnections,
                                  }.toList()..sort())
                                    DownpeedSegment<int>(
                                      value: count,
                                      label: '$count',
                                    ),
                                ],
                                selected: controller
                                    .engineSettingsService
                                    .bitTorrent!
                                    .maxPeerConnections,
                                onSelected: controller.selectBTPeerConnections,
                              ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.shield,
                        title: L10nKeys.settingsBTDiscovery.tr,
                        description: L10nKeys.settingsBTDiscoveryDescription.tr,
                        control: _LockedPolicyValue(
                          key: const ValueKey('settings-bt-discovery-locked'),
                          safe:
                              controller
                                  .engineSettingsService
                                  .bitTorrent
                                  ?.restrictedCapabilitiesDisabled ??
                              false,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.upload,
                        title: L10nKeys.settingsBTTransferPolicy.tr,
                        description:
                            L10nKeys.settingsBTTransferPolicyDescription.tr,
                        control: _LockedPolicyValue(
                          key: const ValueKey('settings-bt-upload-locked'),
                          safe:
                              controller
                                  .engineSettingsService
                                  .bitTorrent
                                  ?.restrictedCapabilitiesDisabled ??
                              false,
                        ),
                      ),
                    ],
                    SettingsSection.engine => [
                      _SettingsRow(
                        icon: DownpeedIcons.engine,
                        title: _engineTitle(engineState),
                        description: engineInfo == null
                            ? L10nKeys.settingsEngineDescription.tr
                            : L10nKeys.engineVersion.trParams({
                                'version': engineInfo.version,
                              }),
                        control: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const EngineStatusBadge(),
                            const SizedBox(width: DownpeedThemeTokens.spaceXs),
                            IconButton(
                              key: const ValueKey('settings-engine-refresh'),
                              tooltip: L10nKeys.engineRetry.tr,
                              onPressed: controller.refreshEngine,
                              icon: const Icon(DownpeedIcons.retry),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SettingsSection.diagnostics => [
                      _SettingsRow(
                        icon: DownpeedIcons.path,
                        title: L10nKeys.settingsDiagnosticsDataDirectory.tr,
                        description: L10nKeys
                            .settingsDiagnosticsDataDirectoryDescription
                            .tr,
                        control: _DiagnosticPathValue(
                          key: const ValueKey(
                            'settings-diagnostics-data-directory',
                          ),
                          path:
                              diagnostics?.storage.dataDirectory ??
                              (diagnosticsLoading
                                  ? L10nKeys.settingsDiagnosticsLoading.tr
                                  : L10nKeys.settingsDiagnosticsUnavailable.tr),
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.database,
                        title: L10nKeys.settingsDiagnosticsDatabase.tr,
                        description:
                            L10nKeys.settingsDiagnosticsDatabaseDescription.tr,
                        control: _DiagnosticPathValue(
                          key: const ValueKey('settings-diagnostics-database'),
                          path:
                              diagnostics?.storage.databasePath ??
                              (diagnosticsLoading
                                  ? L10nKeys.settingsDiagnosticsLoading.tr
                                  : L10nKeys.settingsDiagnosticsUnavailable.tr),
                          detail: diagnostics == null
                              ? null
                              : diagnostics.storage.databaseAvailable
                              ? formatBytes(
                                  diagnostics.storage.databaseSizeBytes,
                                )
                              : L10nKeys
                                    .settingsDiagnosticsDatabaseUnavailable
                                    .tr,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.logs,
                        title: L10nKeys.settingsDiagnosticsLogs.tr,
                        description:
                            L10nKeys.settingsDiagnosticsLogsDescription.tr,
                        control: _DiagnosticPathValue(
                          key: const ValueKey('settings-diagnostics-logs'),
                          path: diagnostics == null
                              ? (diagnosticsLoading
                                    ? L10nKeys.settingsDiagnosticsLoading.tr
                                    : L10nKeys
                                          .settingsDiagnosticsUnavailable
                                          .tr)
                              : diagnostics.storage.logsAvailable
                              ? diagnostics.storage.logPath
                              : L10nKeys.settingsDiagnosticsLogsUnavailable.tr,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.diagnostics,
                        title: L10nKeys.settingsDiagnosticsTasks.tr,
                        description:
                            L10nKeys.settingsDiagnosticsTasksDescription.tr,
                        control: _SettingsValue(
                          key: const ValueKey('settings-diagnostics-tasks'),
                          value: diagnostics == null
                              ? (diagnosticsLoading
                                    ? L10nKeys.settingsDiagnosticsLoading.tr
                                    : L10nKeys
                                          .settingsDiagnosticsUnavailable
                                          .tr)
                              : _diagnosticTaskSummary(diagnostics.tasks),
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.archive,
                        title: L10nKeys.settingsDiagnosticsExport.tr,
                        description:
                            L10nKeys.settingsDiagnosticsExportDescription.tr,
                        control: FilledButton.icon(
                          key: const ValueKey('settings-diagnostics-export'),
                          onPressed: diagnostics == null || diagnosticsExporting
                              ? null
                              : controller.exportDiagnostics,
                          icon: diagnosticsExporting
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(DownpeedIcons.archive),
                          label: Text(
                            diagnosticsExporting
                                ? L10nKeys.settingsDiagnosticsExporting.tr
                                : L10nKeys.settingsDiagnosticsExportAction.tr,
                          ),
                        ),
                      ),
                    ],
                    SettingsSection.about => [
                      _SettingsRow(
                        icon: DownpeedIcons.about,
                        title: L10nKeys.settingsAboutAppVersion.tr,
                        description:
                            L10nKeys.settingsAboutAppVersionDescription.tr,
                        control: _SettingsValue(
                          key: const ValueKey('settings-app-version'),
                          value: DownpeedBuildInfo.displayVersion,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.engine,
                        title: L10nKeys.settingsAboutEngineVersion.tr,
                        description: engineInfo == null
                            ? L10nKeys.settingsAboutEngineUnavailable.tr
                            : L10nKeys.settingsAboutEngineVersionDescription
                                  .trParams({
                                    'api': engineInfo.apiVersion,
                                    'platform':
                                        '${engineInfo.os}/${engineInfo.arch}',
                                  }),
                        control: _SettingsValue(
                          key: const ValueKey('settings-about-engine-version'),
                          value:
                              engineInfo?.version ?? L10nKeys.engineOffline.tr,
                        ),
                      ),
                      _SettingsRow(
                        icon: DownpeedIcons.licenses,
                        title: L10nKeys.settingsAboutLicenses.tr,
                        description:
                            L10nKeys.settingsAboutLicensesDescription.tr,
                        control: TextButton.icon(
                          key: const ValueKey('settings-open-licenses'),
                          onPressed: () => controller.openLicenses(context),
                          icon: const Icon(DownpeedIcons.licenses),
                          label: Text(L10nKeys.settingsAboutOpenLicenses.tr),
                        ),
                      ),
                    ],
                  },
                ),
                if (section == SettingsSection.appearance) ...[
                  const SizedBox(height: 14),
                  const _BrandMarkPreviews(),
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-appearance-note'),
                    title: L10nKeys.settingsAppearanceNoteTitle.tr,
                    body: L10nKeys.settingsAppearanceNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.workspace) ...[
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-workspace-note'),
                    title: L10nKeys.settingsWorkspaceNoteTitle.tr,
                    body: L10nKeys.settingsWorkspaceNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.notifications) ...[
                  if (controller.startupService.failure.value != null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-startup-error'),
                      title: L10nKeys.settingsStartupErrorTitle.tr,
                      body: _startupFailureMessage(
                        controller.startupService.failure.value!,
                      ),
                    ),
                  ] else if (!controller.startupService.isLoading.value &&
                      !controller.startupService.supported.value) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-startup-unavailable'),
                      title: L10nKeys.settingsStartupUnavailableTitle.tr,
                      body: L10nKeys.settingsStartupUnavailableBody.tr,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-notifications-note'),
                    title: L10nKeys.settingsNotificationsNoteTitle.tr,
                    body: L10nKeys.settingsNotificationsNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.downloads) ...[
                  if (controller.engineSettingsService.errorMessage.value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-downloads-error'),
                      title: L10nKeys.settingsDownloadDirectoryErrorTitle.tr,
                      body:
                          controller.engineSettingsService.errorMessage.value!,
                    ),
                  ],
                  if (controller
                          .engineSettingsService
                          .fileConflictErrorMessage
                          .value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-file-conflict-error'),
                      title: L10nKeys.settingsFileConflictPolicyErrorTitle.tr,
                      body: controller
                          .engineSettingsService
                          .fileConflictErrorMessage
                          .value!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-downloads-note'),
                    title: L10nKeys.settingsDownloadsNoteTitle.tr,
                    body: L10nKeys.settingsDownloadsNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.scheduler) ...[
                  if (controller
                          .engineSettingsService
                          .schedulerErrorMessage
                          .value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-scheduler-error'),
                      title: L10nKeys.settingsSchedulerErrorTitle.tr,
                      body: controller
                          .engineSettingsService
                          .schedulerErrorMessage
                          .value!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-scheduler-note'),
                    title: L10nKeys.settingsSchedulerNoteTitle.tr,
                    body: L10nKeys.settingsSchedulerNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.bitTorrent) ...[
                  if (controller
                          .engineSettingsService
                          .btPolicyErrorMessage
                          .value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-bt-error'),
                      title: L10nKeys.settingsBTPolicyErrorTitle.tr,
                      body: controller
                          .engineSettingsService
                          .btPolicyErrorMessage
                          .value!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-bt-note'),
                    title: L10nKeys.settingsBTPolicyNoteTitle.tr,
                    body: L10nKeys.settingsBTPolicyNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.engine) ...[
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-engine-note'),
                    title: L10nKeys.settingsEngineNoteTitle.tr,
                    body: L10nKeys.settingsEngineNoteBody.tr,
                  ),
                ],
                if (section == SettingsSection.diagnostics) ...[
                  if (controller.diagnosticsService.loadErrorMessage.value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-diagnostics-load-error'),
                      title: L10nKeys.settingsDiagnosticsLoadErrorTitle.tr,
                      body:
                          controller.diagnosticsService.loadErrorMessage.value!,
                      action: OutlinedButton.icon(
                        key: const ValueKey('settings-diagnostics-refresh'),
                        onPressed: diagnosticsLoading
                            ? null
                            : controller.refreshDiagnostics,
                        icon: const Icon(DownpeedIcons.retry),
                        label: Text(L10nKeys.settingsDiagnosticsRefresh.tr),
                      ),
                    ),
                  ],
                  if (controller.diagnosticsService.exportErrorMessage.value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-diagnostics-export-error'),
                      title: L10nKeys.settingsDiagnosticsExportErrorTitle.tr,
                      body: controller
                          .diagnosticsService
                          .exportErrorMessage
                          .value!,
                    ),
                  ],
                  if (controller.diagnosticsService.savedArchivePath.value !=
                      null) ...[
                    const SizedBox(height: 14),
                    _SettingsPreferenceNote(
                      key: const ValueKey('settings-diagnostics-success'),
                      title: L10nKeys.settingsDiagnosticsExportSuccessTitle.tr,
                      body: L10nKeys.settingsDiagnosticsExportSuccessBody
                          .trParams({
                            'path': controller
                                .diagnosticsService
                                .savedArchivePath
                                .value!,
                          }),
                      action:
                          controller.diagnosticsService.canRevealSavedArchive
                          ? TextButton.icon(
                              key: const ValueKey(
                                'settings-diagnostics-reveal',
                              ),
                              onPressed: controller.revealDiagnosticArchive,
                              icon: const Icon(DownpeedIcons.revealFile),
                              label: Text(
                                L10nKeys.settingsDiagnosticsReveal.tr,
                              ),
                            )
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-diagnostics-privacy'),
                    title: L10nKeys.settingsDiagnosticsPrivacyTitle.tr,
                    body: L10nKeys.settingsDiagnosticsPrivacyBody.tr,
                  ),
                ],
                if (section == SettingsSection.about) ...[
                  const SizedBox(height: 14),
                  _SettingsPreferenceNote(
                    key: const ValueKey('settings-about-note'),
                    title: L10nKeys.settingsAboutNoteTitle.tr,
                    body: L10nKeys.settingsAboutNoteBody.tr,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SettingsPreferenceNote extends StatelessWidget {
  const _SettingsPreferenceNote({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _settingsCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              DownpeedIcons.info,
              size: DownpeedThemeTokens.iconSize,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMarkPreviews extends StatelessWidget {
  const _BrandMarkPreviews();

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('settings-logo-previews'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _settingsCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  DownpeedIcons.about,
                  size: DownpeedThemeTokens.iconSize,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10nKeys.settingsLogoPreview.tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      L10nKeys.settingsLogoPreviewDescription.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 440;
              final previews = [
                _BrandSurfacePreview(
                  key: const ValueKey('settings-logo-light-preview'),
                  markKey: const ValueKey('settings-logo-light-mark'),
                  brightness: Brightness.light,
                  label: L10nKeys.settingsLogoPreviewLight.tr,
                ),
                _BrandSurfacePreview(
                  key: const ValueKey('settings-logo-dark-preview'),
                  markKey: const ValueKey('settings-logo-dark-mark'),
                  brightness: Brightness.dark,
                  label: L10nKeys.settingsLogoPreviewDark.tr,
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    previews.first,
                    const SizedBox(height: 10),
                    previews.last,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: previews.first),
                  const SizedBox(width: 10),
                  Expanded(child: previews.last),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BrandSurfacePreview extends StatelessWidget {
  const _BrandSurfacePreview({
    required this.markKey,
    required this.brightness,
    required this.label,
    super.key,
  });

  final Key markKey;
  final Brightness brightness;
  final String label;

  @override
  Widget build(BuildContext context) {
    final previewColors = DownpeedThemeTokens.colorsFor(brightness);
    return Semantics(
      label: label,
      image: true,
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          color: previewColors.workspace,
          border: Border.all(color: previewColors.borderStrong),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DownpeedBrandMark(
              key: markKey,
              size: 54,
              color: previewColors.text,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: previewColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsValue extends StatelessWidget {
  const _SettingsValue({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      constraints: const BoxConstraints(
        minHeight: DownpeedThemeTokens.controlHeight,
        maxWidth: 360,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DiagnosticPathValue extends StatelessWidget {
  const _DiagnosticPathValue({required this.path, this.detail, super.key});

  final String path;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Tooltip(
      message: path,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: DownpeedThemeTokens.controlHeight,
          maxWidth: 360,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(
                detail!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedPolicyValue extends StatelessWidget {
  const _LockedPolicyValue({required this.safe, super.key});

  final bool safe;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      constraints: const BoxConstraints(
        minHeight: DownpeedThemeTokens.controlHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        border: Border.all(color: safe ? colors.border : colors.danger),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            safe ? DownpeedIcons.locked : DownpeedIcons.issues,
            size: 13,
            color: safe ? colors.textSecondary : colors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            safe
                ? L10nKeys.settingsBTLocked.tr
                : L10nKeys.taskBTUnexpectedEnabled.tr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: safe ? colors.textSecondary : colors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(
          color: colors.border.withValues(alpha: _settingsCardBorderAlpha),
        ),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: colors.border.withValues(alpha: _settingsDividerAlpha),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.control,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final descriptionBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: DownpeedThemeTokens.iconSize,
                color: context.downpeedColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.downpeedColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.all(14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    descriptionBlock,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: control),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: descriptionBlock),
                    const SizedBox(width: 20),
                    control,
                  ],
                ),
        );
      },
    );
  }
}

class _SettingsNavigationGroup {
  const _SettingsNavigationGroup({
    required this.label,
    required this.destinations,
  });

  final String label;
  final List<_SettingsNavigationDestination> destinations;
}

class _SettingsNavigationDestination {
  const _SettingsNavigationDestination({
    required this.key,
    required this.icon,
    required this.label,
    required this.section,
  });

  final Key key;
  final IconData icon;
  final String label;
  final SettingsSection section;
}

List<_SettingsNavigationGroup> _settingsNavigationGroups() => [
  _SettingsNavigationGroup(
    label: L10nKeys.settingsNavigationDownloads.tr,
    destinations: [
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-downloads'),
        icon: DownpeedIcons.folder,
        label: L10nKeys.settingsDownloads.tr,
        section: SettingsSection.downloads,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-scheduler'),
        icon: DownpeedIcons.scheduler,
        label: L10nKeys.settingsScheduler.tr,
        section: SettingsSection.scheduler,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-bt'),
        icon: DownpeedIcons.magnet,
        label: L10nKeys.settingsBT.tr,
        section: SettingsSection.bitTorrent,
      ),
    ],
  ),
  _SettingsNavigationGroup(
    label: L10nKeys.settingsNavigationPreferences.tr,
    destinations: [
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-appearance'),
        icon: DownpeedIcons.lightTheme,
        label: L10nKeys.settingsAppearance.tr,
        section: SettingsSection.appearance,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-workspace'),
        icon: DownpeedIcons.layout,
        label: L10nKeys.settingsWorkspace.tr,
        section: SettingsSection.workspace,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-notifications'),
        icon: DownpeedIcons.notifications,
        label: L10nKeys.settingsNotifications.tr,
        section: SettingsSection.notifications,
      ),
    ],
  ),
  _SettingsNavigationGroup(
    label: L10nKeys.settingsNavigationSystem.tr,
    destinations: [
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-engine'),
        icon: DownpeedIcons.engine,
        label: L10nKeys.settingsEngine.tr,
        section: SettingsSection.engine,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-diagnostics'),
        icon: DownpeedIcons.diagnostics,
        label: L10nKeys.settingsDiagnostics.tr,
        section: SettingsSection.diagnostics,
      ),
      _SettingsNavigationDestination(
        key: const ValueKey('settings-nav-about'),
        icon: DownpeedIcons.about,
        label: L10nKeys.settingsAbout.tr,
        section: SettingsSection.about,
      ),
    ],
  ),
];

String _settingsSectionTitle(SettingsSection section) => switch (section) {
  SettingsSection.appearance => L10nKeys.settingsAppearance.tr,
  SettingsSection.workspace => L10nKeys.settingsWorkspace.tr,
  SettingsSection.notifications => L10nKeys.settingsNotifications.tr,
  SettingsSection.downloads => L10nKeys.settingsDownloads.tr,
  SettingsSection.scheduler => L10nKeys.settingsScheduler.tr,
  SettingsSection.bitTorrent => L10nKeys.settingsBT.tr,
  SettingsSection.engine => L10nKeys.settingsEngine.tr,
  SettingsSection.diagnostics => L10nKeys.settingsDiagnostics.tr,
  SettingsSection.about => L10nKeys.settingsAbout.tr,
};

String _settingsSectionDescription(SettingsSection section) =>
    switch (section) {
      SettingsSection.appearance => L10nKeys.settingsAppearanceDescription.tr,
      SettingsSection.workspace => L10nKeys.settingsWorkspaceDescription.tr,
      SettingsSection.notifications =>
        L10nKeys.settingsNotificationsDescription.tr,
      SettingsSection.downloads => L10nKeys.settingsDownloadsDescription.tr,
      SettingsSection.scheduler => L10nKeys.settingsSchedulerDescription.tr,
      SettingsSection.bitTorrent => L10nKeys.settingsBTDescription.tr,
      SettingsSection.engine => L10nKeys.settingsEngineSectionDescription.tr,
      SettingsSection.diagnostics => L10nKeys.settingsDiagnosticsDescription.tr,
      SettingsSection.about => L10nKeys.settingsAboutDescription.tr,
    };

String _diagnosticTaskSummary(DiagnosticTaskSummary summary) => L10nKeys
    .settingsDiagnosticsTasksValue
    .trParams({'total': '${summary.total}', 'active': '${summary.active}'});

List<int> _schedulerRateLimits(int current) => <int>{
  0,
  1 * 1024 * 1024,
  5 * 1024 * 1024,
  10 * 1024 * 1024,
  20 * 1024 * 1024,
  50 * 1024 * 1024,
  100 * 1024 * 1024,
  current,
}.toList()..sort();

String _schedulerRateLabel(int value) => value == 0
    ? L10nKeys.settingsSchedulerUnlimited.tr
    : '${formatBytes(value)}/s';

String _engineTitle(EngineConnectionState state) => switch (state) {
  EngineConnectionState.checking => L10nKeys.engineChecking.tr,
  EngineConnectionState.online => L10nKeys.engineOnline.tr,
  EngineConnectionState.offline => L10nKeys.engineOffline.tr,
};

String _startupFailureMessage(StartupFailure failure) => switch (failure) {
  StartupFailure.read => L10nKeys.settingsStartupReadError.tr,
  StartupFailure.update => L10nKeys.settingsStartupUpdateError.tr,
  StartupFailure.verification => L10nKeys.settingsStartupVerificationError.tr,
};
