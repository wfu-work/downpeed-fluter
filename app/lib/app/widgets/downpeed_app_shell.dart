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
const _macOSSidebarToggleExtent = 40.0;
const _macOSCollapsedSidebarWidth =
    _macOSWindowControlsWidth + _macOSSidebarToggleExtent + 4;
const _macOSTitleBarHeight = 38.0;

enum AppDestination { overview, tasks, network, settings }

class DownpeedAppShell extends StatefulWidget {
  const DownpeedAppShell({
    super.key,
    required this.child,
    required this.selectedDestination,
  });

  final Widget child;
  final AppDestination selectedDestination;

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
            backgroundColor: Colors.transparent,
            body: DecoratedBox(
              decoration: context.downpeedWorkspaceDecoration,
              child: showSidebar
                  ? Row(
                      children: [
                        _SidebarPane(
                          expanded: expanded,
                          expandedWidth: expandedWidth,
                          resizing: _isResizingSidebar,
                          selectedDestination: widget.selectedDestination,
                          onSelected: _openDestination,
                          onToggle: () => unawaited(
                            _preferences.setSidebarExpanded(!expanded),
                          ),
                          onResizeStart: () =>
                              _startSidebarResize(expandedWidth),
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
                          selectedDestination: widget.selectedDestination,
                          onSelected: _openDestination,
                        ),
                      ],
                    ),
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

  void _openDestination(AppDestination destination) {
    if (destination == widget.selectedDestination) return;
    final route = switch (destination) {
      AppDestination.overview => Routes.overview,
      AppDestination.tasks => Routes.tasks,
      AppDestination.network => Routes.network,
      AppDestination.settings => Routes.settings,
    };
    if (Get.currentRoute.split('?').first == route) return;
    Get.offAllNamed<void>(route);
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    required this.expanded,
    required this.expandedWidth,
    required this.resizing,
    required this.selectedDestination,
    required this.onSelected,
    required this.onToggle,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final bool expanded;
  final double expandedWidth;
  final bool resizing;
  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onSelected;
  final VoidCallback onToggle;
  final VoidCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final collapsedWidth = defaultTargetPlatform == TargetPlatform.macOS
        ? _macOSCollapsedSidebarWidth
        : DownpeedThemeTokens.sidebarCollapsedWidth;
    return SizedBox(
      key: const ValueKey('sidebar-pane'),
      width: expanded ? expandedWidth : collapsedWidth,
      child: DecoratedBox(
        decoration: context.downpeedSidebarDecoration.copyWith(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: defaultTargetPlatform != TargetPlatform.macOS,
              child: expanded
                  ? _ExpandedSidebar(
                      selectedDestination: selectedDestination,
                      onSelected: onSelected,
                      onToggle: onToggle,
                    )
                  : _CollapsedSidebar(
                      selectedDestination: selectedDestination,
                      onSelected: onSelected,
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
    required this.selectedDestination,
    required this.onSelected,
    required this.onToggle,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onSelected;
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
          const SizedBox(height: 6),
          for (final item in _navigationItems)
            _NavigationTile(
              key: ValueKey('sidebar-destination-${item.destination.name}'),
              icon: item.icon,
              label: item.label,
              selected: selectedDestination == item.destination,
              onTap: () => onSelected(item.destination),
            ),
          const Spacer(),
          Divider(color: context.downpeedColors.border.withValues(alpha: 0.72)),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _NavigationTile(
                  key: const ValueKey('sidebar-settings'),
                  icon: DownpeedIcons.settings,
                  label: L10nKeys.navSettings.tr,
                  selected: selectedDestination == AppDestination.settings,
                  onTap: () => onSelected(AppDestination.settings),
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
    required this.selectedDestination,
    required this.onSelected,
    required this.onToggle,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return Column(
      children: [
        if (isMacOS)
          SizedBox(
            key: const ValueKey('sidebar-collapsed-titlebar'),
            height: _macOSTitleBarHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  key: const ValueKey('sidebar-toggle-collapsed'),
                  tooltip: L10nKeys.sidebarExpand.tr,
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(
                      DownpeedThemeTokens.touchTarget,
                    ),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(DownpeedIcons.sidebarOpen),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: DownpeedThemeTokens.spaceSm),
        const DownpeedBrandMark(size: 22),
        if (!isMacOS) ...[
          const SizedBox(height: DownpeedThemeTokens.spaceXs),
          IconButton(
            key: const ValueKey('sidebar-toggle-collapsed'),
            tooltip: L10nKeys.sidebarExpand.tr,
            onPressed: onToggle,
            icon: const Icon(DownpeedIcons.sidebarOpen),
          ),
        ],
        const SizedBox(height: DownpeedThemeTokens.spaceSm),
        const Divider(indent: 12, endIndent: 12),
        for (final item in _navigationItems)
          _CollapsedDestination(
            key: ValueKey(
              'sidebar-destination-${item.destination.name}-collapsed',
            ),
            icon: item.icon,
            label: item.label,
            selected: selectedDestination == item.destination,
            onPressed: () => onSelected(item.destination),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: DownpeedThemeTokens.spaceSm),
          child: _CollapsedDestination(
            key: const ValueKey('sidebar-settings-collapsed'),
            icon: DownpeedIcons.settings,
            label: L10nKeys.navSettings.tr,
            selected: selectedDestination == AppDestination.settings,
            onPressed: () => onSelected(AppDestination.settings),
          ),
        ),
      ],
    );
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
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
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    final backgroundColor = selected
        ? colors.sidebarSelection
        : _hovered
        ? colors.sidebarSelection.withValues(alpha: 0.38)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: DownpeedThemeTokens.spaceXs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          key: selected ? const ValueKey('sidebar-selected-indicator') : null,
          duration: animationDuration,
          curve: Curves.easeOutCubic,
          height: DownpeedThemeTokens.sidebarNavigationHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              DownpeedThemeTokens.radiusLarge,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(
                DownpeedThemeTokens.radiusLarge,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: DownpeedThemeTokens.sidebarIconSize,
                      color: selected ? colors.text : colors.textSecondary,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? colors.text : colors.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: IconButton(
        tooltip: label,
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
    required this.selectedDestination,
    required this.onSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = <_NavigationItem>[
      ..._navigationItems,
      _NavigationItem(
        AppDestination.settings,
        DownpeedIcons.settings,
        L10nKeys.navSettings,
      ),
    ];
    return NavigationBar(
      selectedIndex: destinations.indexWhere(
        (item) => item.destination == selectedDestination,
      ),
      onDestinationSelected: (index) =>
          onSelected(destinations[index].destination),
      destinations: [
        for (final item in destinations)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.destination, this.icon, this.labelKey);

  final AppDestination destination;
  final IconData icon;
  final String labelKey;

  String get label => labelKey.tr;
}

const _navigationItems = <_NavigationItem>[
  _NavigationItem(
    AppDestination.overview,
    DownpeedIcons.overview,
    L10nKeys.navOverview,
  ),
  _NavigationItem(
    AppDestination.tasks,
    DownpeedIcons.download,
    L10nKeys.navTasks,
  ),
  _NavigationItem(
    AppDestination.network,
    DownpeedIcons.connections,
    L10nKeys.navNetwork,
  ),
];
