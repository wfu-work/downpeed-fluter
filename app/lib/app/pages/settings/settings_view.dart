import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/engine_info.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/engine_status_badge.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DownpeedAppShell(
      settingsSelected: true,
      onTaskFilterChanged: controller.openTaskFilter,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SettingsHeader(),
            Expanded(child: _SettingsContent(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('settings-page'),
      padding: const EdgeInsets.fromLTRB(
        DownpeedThemeTokens.pagePadding,
        14,
        DownpeedThemeTokens.pagePadding,
        13,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.downpeedColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10nKeys.settingsTitle.tr,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            L10nKeys.settingsSubtitle.tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.downpeedColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locale = controller.appService.locale.value.languageCode;
      final engineState = controller.engineService.state.value;
      final engineInfo = controller.engineService.info.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(DownpeedThemeTokens.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsSection(
                  title: L10nKeys.settingsAppearance.tr,
                  children: [
                    _SettingsRow(
                      icon: DownpeedIcons.systemTheme,
                      title: L10nKeys.settingsTheme.tr,
                      description: L10nKeys.settingsThemeDescription.tr,
                      control: SegmentedButton<ThemeMode>(
                        key: const ValueKey('settings-theme-control'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(DownpeedIcons.systemTheme),
                            label: Text(L10nKeys.settingsThemeSystem.tr),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(DownpeedIcons.lightTheme),
                            label: Text(L10nKeys.settingsThemeLight.tr),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(DownpeedIcons.darkTheme),
                            label: Text(L10nKeys.settingsThemeDark.tr),
                          ),
                        ],
                        selected: {controller.appService.themeMode.value},
                        onSelectionChanged: controller.selectTheme,
                      ),
                    ),
                    _SettingsRow(
                      icon: DownpeedIcons.language,
                      title: L10nKeys.settingsLanguage.tr,
                      description: L10nKeys.settingsLanguageDescription.tr,
                      control: SegmentedButton<String>(
                        key: const ValueKey('settings-language-control'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: 'zh',
                            label: Text(L10nKeys.settingsLanguageChinese.tr),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text(L10nKeys.settingsLanguageEnglish.tr),
                          ),
                        ],
                        selected: {locale == 'en' ? 'en' : 'zh'},
                        onSelectionChanged: controller.selectLanguage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DownpeedThemeTokens.spaceXl),
                _SettingsSection(
                  title: L10nKeys.settingsWorkspace.tr,
                  children: [
                    _SettingsRow(
                      icon: DownpeedIcons.layout,
                      title: L10nKeys.settingsSidebarExpanded.tr,
                      description:
                          L10nKeys.settingsSidebarExpandedDescription.tr,
                      control: Switch(
                        key: const ValueKey('settings-sidebar-expanded'),
                        value: controller.preferences.sidebarExpanded.value,
                        onChanged: controller.setSidebarExpanded,
                      ),
                    ),
                    _SettingsRow(
                      icon: DownpeedIcons.sidebarOpen,
                      title: L10nKeys.settingsSidebarWidth.tr,
                      description: L10nKeys.settingsSidebarWidthDescription.tr,
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
                ),
                const SizedBox(height: DownpeedThemeTokens.spaceXl),
                _SettingsSection(
                  title: L10nKeys.settingsEngine.tr,
                  children: [
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
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  String _engineTitle(EngineConnectionState state) => switch (state) {
    EngineConnectionState.checking => L10nKeys.engineChecking.tr,
    EngineConnectionState.online => L10nKeys.engineOnline.tr,
    EngineConnectionState.offline => L10nKeys.engineOffline.tr,
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(
              DownpeedThemeTokens.radiusLarge,
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
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
        final compact = constraints.maxWidth < 560;
        final descriptionBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 17,
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
          padding: const EdgeInsets.all(16),
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
                    const SizedBox(width: 24),
                    control,
                  ],
                ),
        );
      },
    );
  }
}
