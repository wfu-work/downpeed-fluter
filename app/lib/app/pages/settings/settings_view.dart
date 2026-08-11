import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/engine_info.dart';
import '../../widgets/downpeed_controls.dart';
import '../../widgets/engine_status_badge.dart';
import 'settings_controller.dart';

const _settingsWideBreakpoint = 700.0;
const _settingsNavigationWidth = 214.0;
const _settingsContentMaxWidth = 760.0;
const _macOSTitleBarHeight = 38.0;

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
      backgroundColor: context.downpeedColors.workspace,
      body: Row(
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
        backgroundColor: context.downpeedColors.workspace,
        body: SafeArea(
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
      decoration: BoxDecoration(
        color: compact ? colors.workspace : colors.sidebar,
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
      return ColoredBox(
        color: context.downpeedColors.workspace,
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
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, indent: 14, endIndent: 14),
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
    ],
  ),
];

String _settingsSectionTitle(SettingsSection section) => switch (section) {
  SettingsSection.appearance => L10nKeys.settingsAppearance.tr,
  SettingsSection.workspace => L10nKeys.settingsWorkspace.tr,
  SettingsSection.engine => L10nKeys.settingsEngine.tr,
};

String _settingsSectionDescription(SettingsSection section) =>
    switch (section) {
      SettingsSection.appearance => L10nKeys.settingsAppearanceDescription.tr,
      SettingsSection.workspace => L10nKeys.settingsWorkspaceDescription.tr,
      SettingsSection.engine => L10nKeys.settingsEngineSectionDescription.tr,
    };

String _engineTitle(EngineConnectionState state) => switch (state) {
  EngineConnectionState.checking => L10nKeys.engineChecking.tr,
  EngineConnectionState.online => L10nKeys.engineOnline.tr,
  EngineConnectionState.offline => L10nKeys.engineOffline.tr,
};
