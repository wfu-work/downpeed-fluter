import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/localization/l10n_keys.dart';
import '../../configs/theme/downpeed_icons.dart';
import '../../configs/theme/downpeed_theme_tokens.dart';
import '../../services/app_service.dart';
import '../../services/preferences_service.dart';
import '../routes/app_pages.dart';
import 'brand_mark.dart';
import 'engine_status_badge.dart';

const _macOSWindowControlsWidth = 76.0;
const _macOSTitleBarHeight = 38.0;

class DownpeedAppShell extends StatefulWidget {
  const DownpeedAppShell({
    super.key,
    required this.child,
    this.selectedTaskFilter = 0,
    this.onTaskFilterChanged,
    this.taskCounts,
    this.settingsSelected = false,
  });

  final Widget child;
  final int selectedTaskFilter;
  final ValueChanged<int>? onTaskFilterChanged;
  final List<int>? taskCounts;
  final bool settingsSelected;

  @override
  State<DownpeedAppShell> createState() => _DownpeedAppShellState();
}

class _DownpeedAppShellState extends State<DownpeedAppShell> {
  bool _isResizingSidebar = false;

  PreferencesService get _preferences => PreferencesService.to;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 720;
        final maxSidebarWidth = (constraints.maxWidth - 480)
            .clamp(
              DownpeedThemeTokens.sidebarMinWidth,
              DownpeedThemeTokens.sidebarMaxWidth,
            )
            .toDouble();
        return Obx(() {
          final expanded = _preferences.sidebarExpanded.value;
          final expandedWidth = _preferences.sidebarWidth.value
              .clamp(DownpeedThemeTokens.sidebarMinWidth, maxSidebarWidth)
              .toDouble();
          return Scaffold(
            backgroundColor: context.downpeedColors.workspace,
            body: showSidebar
                ? Row(
                    children: [
                      _SidebarPane(
                        expanded: expanded,
                        expandedWidth: expandedWidth,
                        resizing: _isResizingSidebar,
                        selectedIndex: widget.selectedTaskFilter,
                        settingsSelected: widget.settingsSelected,
                        counts: widget.taskCounts,
                        onSelected: widget.onTaskFilterChanged,
                        onSettingsSelected: _openSettings,
                        onToggle: () => unawaited(
                          _preferences.setSidebarExpanded(!expanded),
                        ),
                        onResizeStart: () => _startSidebarResize(expandedWidth),
                        onResizeUpdate: (delta) =>
                            _updateSidebarWidth(delta, maxSidebarWidth),
                        onResizeEnd: _finishSidebarResize,
                      ),
                      Expanded(child: widget.child),
                    ],
                  )
                : Column(
                    children: [
                      const _CompactHeader(),
                      Expanded(child: widget.child),
                      _CompactNavigation(
                        selectedIndex: widget.selectedTaskFilter,
                        settingsSelected: widget.settingsSelected,
                        onSelected: widget.onTaskFilterChanged,
                        onSettingsSelected: _openSettings,
                      ),
                    ],
                  ),
          );
        });
      },
    );
  }

  void _startSidebarResize(double renderedWidth) {
    if (_isResizingSidebar) return;
    _preferences.updateSidebarWidth(renderedWidth);
    setState(() => _isResizingSidebar = true);
  }

  void _updateSidebarWidth(double delta, double maxWidth) {
    _preferences.updateSidebarWidth(
      (_preferences.sidebarWidth.value + delta)
          .clamp(DownpeedThemeTokens.sidebarMinWidth, maxWidth)
          .toDouble(),
    );
  }

  void _finishSidebarResize() {
    if (!_isResizingSidebar) return;
    setState(() => _isResizingSidebar = false);
    unawaited(_preferences.persistSidebarWidth());
  }

  void _openSettings() {
    if (Get.currentRoute.split('?').first == Routes.settings) return;
    Get.toNamed<void>(Routes.settings);
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    required this.expanded,
    required this.expandedWidth,
    required this.resizing,
    required this.selectedIndex,
    required this.settingsSelected,
    required this.counts,
    required this.onSelected,
    required this.onSettingsSelected,
    required this.onToggle,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final bool expanded;
  final double expandedWidth;
  final bool resizing;
  final int selectedIndex;
  final bool settingsSelected;
  final List<int>? counts;
  final ValueChanged<int>? onSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onToggle;
  final VoidCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final collapsedWidth = defaultTargetPlatform == TargetPlatform.macOS
        ? _macOSWindowControlsWidth
        : DownpeedThemeTokens.sidebarCollapsedWidth;
    return SizedBox(
      key: const ValueKey('sidebar-pane'),
      width: expanded ? expandedWidth : collapsedWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.sidebar,
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: defaultTargetPlatform != TargetPlatform.macOS,
              child: expanded
                  ? _ExpandedSidebar(
                      selectedIndex: selectedIndex,
                      settingsSelected: settingsSelected,
                      counts: counts,
                      onSelected: onSelected,
                      onSettingsSelected: onSettingsSelected,
                      onToggle: onToggle,
                    )
                  : _CollapsedSidebar(
                      selectedIndex: selectedIndex,
                      settingsSelected: settingsSelected,
                      counts: counts,
                      onSelected: onSelected,
                      onSettingsSelected: onSettingsSelected,
                      onToggle: onToggle,
                    ),
            ),
            if (expanded)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 10,
                child: _SidebarResizeHandle(
                  resizing: resizing,
                  onResizeStart: onResizeStart,
                  onResizeUpdate: onResizeUpdate,
                  onResizeEnd: onResizeEnd,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.selectedIndex,
    required this.settingsSelected,
    required this.counts,
    required this.onSelected,
    required this.onSettingsSelected,
    required this.onToggle,
  });

  final int selectedIndex;
  final bool settingsSelected;
  final List<int>? counts;
  final ValueChanged<int>? onSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final topHeight = defaultTargetPlatform == TargetPlatform.macOS
        ? _macOSTitleBarHeight
        : 42.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: topHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey('sidebar-toggle-expanded'),
                tooltip: L10nKeys.sidebarCollapse.tr,
                onPressed: onToggle,
                icon: const Icon(DownpeedIcons.sidebarClose),
              ),
            ),
          ),
          const SizedBox(height: DownpeedThemeTokens.spaceSm),
          for (var index = 0; index < _navigationItems.length; index++)
            _NavigationTile(
              key: ValueKey('sidebar-filter-$index'),
              icon: _navigationItems[index].icon,
              label: _navigationItems[index].label,
              selected: !settingsSelected && selectedIndex == index,
              count: _countAt(index),
              onTap: onSelected == null ? null : () => onSelected!(index),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _NavigationTile(
                  key: const ValueKey('sidebar-settings'),
                  icon: DownpeedIcons.settings,
                  label: L10nKeys.navSettings.tr,
                  selected: settingsSelected,
                  onTap: onSettingsSelected,
                ),
              ),
              const SizedBox(width: DownpeedThemeTokens.spaceXs),
              const _SidebarThemeToggle(),
            ],
          ),
        ],
      ),
    );
  }

  int? _countAt(int index) {
    final values = counts;
    return values != null && index < values.length ? values[index] : null;
  }
}

class _SidebarThemeToggle extends StatelessWidget {
  const _SidebarThemeToggle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: IconButton(
        key: const ValueKey('sidebar-theme-toggle'),
        tooltip: isDark
            ? L10nKeys.sidebarThemeToLight.tr
            : L10nKeys.sidebarThemeToDark.tr,
        onPressed: () => unawaited(
          AppService.to.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
        ),
        icon: Icon(isDark ? DownpeedIcons.lightTheme : DownpeedIcons.darkTheme),
      ),
    );
  }
}

class _CollapsedSidebar extends StatelessWidget {
  const _CollapsedSidebar({
    required this.selectedIndex,
    required this.settingsSelected,
    required this.counts,
    required this.onSelected,
    required this.onSettingsSelected,
    required this.onToggle,
  });

  final int selectedIndex;
  final bool settingsSelected;
  final List<int>? counts;
  final ValueChanged<int>? onSelected;
  final VoidCallback onSettingsSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final topInset = defaultTargetPlatform == TargetPlatform.macOS
        ? _macOSTitleBarHeight
        : DownpeedThemeTokens.spaceSm;
    return Column(
      children: [
        SizedBox(height: topInset),
        const DownpeedBrandMark(size: 22),
        const SizedBox(height: DownpeedThemeTokens.spaceXs),
        IconButton(
          key: const ValueKey('sidebar-toggle-collapsed'),
          tooltip: L10nKeys.sidebarExpand.tr,
          onPressed: onToggle,
          icon: const Icon(DownpeedIcons.sidebarOpen),
        ),
        const SizedBox(height: DownpeedThemeTokens.spaceSm),
        const Divider(indent: 12, endIndent: 12),
        for (var index = 0; index < _navigationItems.length; index++)
          _CollapsedDestination(
            key: ValueKey('sidebar-filter-$index-collapsed'),
            icon: _navigationItems[index].icon,
            label: _navigationItems[index].label,
            count: _countAt(index),
            selected: !settingsSelected && selectedIndex == index,
            onPressed: onSelected == null ? null : () => onSelected!(index),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: DownpeedThemeTokens.spaceSm),
          child: _CollapsedDestination(
            key: const ValueKey('sidebar-settings-collapsed'),
            icon: DownpeedIcons.settings,
            label: L10nKeys.navSettings.tr,
            selected: settingsSelected,
            onPressed: onSettingsSelected,
          ),
        ),
      ],
    );
  }

  int? _countAt(int index) {
    final values = counts;
    return values != null && index < values.length ? values[index] : null;
  }
}

class _SidebarResizeHandle extends StatefulWidget {
  const _SidebarResizeHandle({
    required this.resizing,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final bool resizing;
  final VoidCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.resizing;
    return MouseRegion(
      key: const ValueKey('sidebar-resize-handle'),
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => widget.onResizeStart(),
        onHorizontalDragUpdate: (details) =>
            widget.onResizeUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => widget.onResizeEnd(),
        onHorizontalDragCancel: widget.onResizeEnd,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 2,
            color: active
                ? context.downpeedColors.borderStrong
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _NavigationTile extends StatefulWidget {
  const _NavigationTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.count,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback? onTap;

  @override
  State<_NavigationTile> createState() => _NavigationTileState();
}

class _NavigationTileState extends State<_NavigationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final selected = widget.selected;
    final count = widget.count;
    final hasItems = count != null && count > 0;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final backgroundColor = selected
        ? Color.alphaBlend(
            colors.sidebarSelection.withValues(alpha: 0.7),
            colors.sidebar,
          )
        : _hovered
        ? Color.alphaBlend(
            colors.sidebarSelection.withValues(alpha: 0.34),
            colors.sidebar,
          )
        : Colors.transparent;
    final countBackground = selected
        ? colors.sidebar
        : hasItems
        ? colors.sidebarSelection.withValues(alpha: 0.48)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: DownpeedThemeTokens.spaceXs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          height: DownpeedThemeTokens.controlHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
            border: Border.all(
              color: selected
                  ? colors.border.withValues(alpha: 0.72)
                  : Colors.transparent,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 4,
                    top: 8,
                    bottom: 8,
                    child: AnimatedContainer(
                      key: selected
                          ? const ValueKey('sidebar-selected-indicator')
                          : null,
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      width: 2,
                      decoration: BoxDecoration(
                        color: selected ? colors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          DownpeedThemeTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          widget.icon,
                          size: DownpeedThemeTokens.iconSize,
                          color: selected ? colors.text : colors.textMuted,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: selected
                                      ? colors.text
                                      : colors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                        if (count != null)
                          AnimatedContainer(
                            key: const ValueKey('sidebar-count-badge'),
                            duration: animationDuration,
                            curve: Curves.easeOutCubic,
                            height: 20,
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: countBackground,
                              borderRadius: BorderRadius.circular(
                                DownpeedThemeTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              '$count',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: selected || hasItems
                                        ? colors.textSecondary
                                        : colors.textMuted,
                                    fontWeight: hasItems
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedDestination extends StatelessWidget {
  const _CollapsedDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final tooltip = count == null ? label : '$label · $count';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? context.downpeedColors.sidebarSelection
              : Colors.transparent,
          hoverColor: context.downpeedColors.sidebarSelection,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: const Row(
          children: [
            DownpeedBrandMark(size: 24),
            Spacer(),
            EngineStatusBadge(),
          ],
        ),
      ),
    );
  }
}

class _CompactNavigation extends StatelessWidget {
  const _CompactNavigation({
    required this.selectedIndex,
    required this.settingsSelected,
    required this.onSelected,
    required this.onSettingsSelected,
  });

  final int selectedIndex;
  final bool settingsSelected;
  final ValueChanged<int>? onSelected;
  final VoidCallback onSettingsSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: settingsSelected ? 4 : selectedIndex.clamp(0, 3),
      onDestinationSelected: (index) {
        if (index == 4) {
          onSettingsSelected();
        } else {
          onSelected?.call(index);
        }
      },
      destinations: [
        for (final item in _navigationItems)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
        NavigationDestination(
          icon: const Icon(DownpeedIcons.settings),
          label: L10nKeys.navSettings.tr,
        ),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.icon, this.labelKey);

  final IconData icon;
  final String labelKey;

  String get label => labelKey.tr;
}

const _navigationItems = <_NavigationItem>[
  _NavigationItem(DownpeedIcons.all, L10nKeys.navAll),
  _NavigationItem(DownpeedIcons.active, L10nKeys.navActive),
  _NavigationItem(DownpeedIcons.completed, L10nKeys.navCompleted),
  _NavigationItem(DownpeedIcons.issues, L10nKeys.navIssues),
];
