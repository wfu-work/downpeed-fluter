import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/engine_settings.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/engine_status_badge.dart';
import '../../widgets/task_display.dart';
import 'network_controller.dart';

class NetworkView extends GetView<NetworkController> {
  const NetworkView({super.key});

  @override
  Widget build(BuildContext context) {
    return DownpeedAppShell(
      selectedDestination: AppDestination.network,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NetworkHeader(controller: controller),
            Expanded(child: _NetworkBody(controller: controller)),
          ],
        ),
      ),
    );
  }
}

class _NetworkHeader extends StatelessWidget {
  const _NetworkHeader({required this.controller});

  final NetworkController controller;

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
          final compact = constraints.maxWidth < 700;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      L10nKeys.networkTitle.tr,
                      key: const ValueKey('network-title'),
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
                L10nKeys.networkSubtitle.tr,
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
            children: [
              IconButton(
                key: const ValueKey('network-refresh'),
                tooltip: L10nKeys.networkRefresh.tr,
                onPressed: () => unawaited(controller.refresh()),
                icon: const Icon(DownpeedIcons.retry),
              ),
              OutlinedButton.icon(
                key: const ValueKey('network-open-settings'),
                onPressed: controller.openSettings,
                icon: const Icon(DownpeedIcons.settings),
                label: Text(L10nKeys.networkOpenSettings.tr),
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

class _NetworkBody extends StatelessWidget {
  const _NetworkBody({required this.controller});

  final NetworkController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _buildBody(context));

  Widget _buildBody(BuildContext context) {
    final engineState = controller.engineService.state.value;
    final info = controller.engineService.info.value;
    final settings = controller.settingsService.settings.value;
    final loading = controller.settingsService.isLoading.value;
    final error = controller.settingsService.errorMessage.value;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 720
        ? DownpeedThemeTokens.compactPagePadding
        : DownpeedThemeTokens.spaceXl;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        key: const ValueKey('network-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          24,
          horizontalPadding,
          36,
        ),
        children: [
          if (engineState == EngineConnectionState.checking && info == null)
            const _NetworkMessage(
              key: ValueKey('network-loading'),
              loading: true,
              titleKey: L10nKeys.networkLoading,
              bodyKey: L10nKeys.networkEngineSubtitle,
            )
          else if (engineState == EngineConnectionState.offline && info == null)
            _NetworkMessage(
              key: const ValueKey('network-offline'),
              titleKey: L10nKeys.engineOfflineTitle,
              bodyKey: L10nKeys.networkUnavailable,
              onRetry: controller.refresh,
            )
          else ...[
            if (info != null) _EngineSection(info: info),
            if (info != null) const SizedBox(height: 28),
            if (settings != null) ...[
              _SchedulerSection(settings: settings.scheduler),
              const SizedBox(height: 28),
              _DownloadBoundarySection(settings: settings),
            ] else if (loading)
              const _InlineStatus(
                key: ValueKey('network-settings-loading'),
                loading: true,
                textKey: L10nKeys.networkLoading,
              )
            else
              _InlineStatus(
                key: const ValueKey('network-settings-unavailable'),
                text: error ?? L10nKeys.networkUnavailable.tr,
              ),
            if (settings != null) ...[
              const SizedBox(height: 28),
              _NetworkPolicySection(policy: settings.bitTorrent),
            ],
          ],
        ],
      ),
    );
  }
}

class _EngineSection extends StatelessWidget {
  const _EngineSection({required this.info});

  final EngineInfo info;

  @override
  Widget build(BuildContext context) {
    return _NetworkSection(
      key: const ValueKey('network-engine-section'),
      title: L10nKeys.networkEngine.tr,
      subtitle: L10nKeys.networkEngineSubtitle.tr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 820
              ? 5
              : constraints.maxWidth >= 480
              ? 2
              : 1;
          final values = <_InfoValue>[
            _InfoValue(L10nKeys.networkEngineName.tr, info.name),
            _InfoValue(L10nKeys.networkEngineVersion.tr, info.version),
            _InfoValue(L10nKeys.networkApi.tr, info.apiVersion),
            _InfoValue(L10nKeys.networkRuntime.tr, info.goVersion),
            _InfoValue(
              L10nKeys.networkPlatform.tr,
              '${info.os} · ${info.arch}',
            ),
          ];
          final width = constraints.maxWidth / columns;
          return Wrap(
            children: [
              for (var index = 0; index < values.length; index++)
                SizedBox(
                  width: width,
                  child: _InfoCell(
                    value: values[index],
                    rightBorder: columns > 1 && index % columns != columns - 1,
                    bottomBorder: index < values.length - columns,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SchedulerSection extends StatelessWidget {
  const _SchedulerSection({required this.settings});

  final SchedulerSettings settings;

  @override
  Widget build(BuildContext context) {
    final values = <_InfoValue>[
      _InfoValue(
        L10nKeys.networkMaxConcurrentTasks.tr,
        L10nKeys.networkConcurrentTasksValue.trParams({
          'count': '${settings.maxConcurrentTasks}',
        }),
      ),
      _InfoValue(
        L10nKeys.networkDownloadRateLimit.tr,
        settings.downloadRateLimit == 0
            ? L10nKeys.networkUnlimited.tr
            : '${formatBytes(settings.downloadRateLimit)}/s',
      ),
      _InfoValue(
        L10nKeys.networkAutomaticRetries.tr,
        L10nKeys.networkRetriesValue.trParams({
          'count': '${settings.maxRetries}',
        }),
      ),
    ];
    return _NetworkSection(
      key: const ValueKey('network-scheduler-section'),
      title: L10nKeys.networkScheduler.tr,
      subtitle: L10nKeys.networkSchedulerSubtitle.tr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 3 : 1;
          final width = constraints.maxWidth / columns;
          return Wrap(
            children: [
              for (var index = 0; index < values.length; index++)
                SizedBox(
                  width: width,
                  child: _InfoCell(
                    value: values[index],
                    rightBorder: columns > 1 && index % columns != columns - 1,
                    bottomBorder: index < values.length - columns,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DownloadBoundarySection extends StatelessWidget {
  const _DownloadBoundarySection({required this.settings});

  final EngineSettings settings;

  @override
  Widget build(BuildContext context) {
    return _NetworkSection(
      key: const ValueKey('network-download-boundary'),
      title: L10nKeys.networkDownloads.tr,
      subtitle: L10nKeys.networkDownloadsSubtitle.tr,
      child: Column(
        children: [
          _NetworkDetailRow(
            icon: DownpeedIcons.folder,
            label: L10nKeys.networkDefaultDirectory.tr,
            value: settings.defaultDownloadDirectory,
          ),
          Divider(height: 1, indent: 48, color: context.downpeedColors.border),
          _NetworkDetailRow(
            icon: DownpeedIcons.connections,
            label: L10nKeys.networkPeerBudget.tr,
            value: L10nKeys.networkPeerBudgetValue.trParams({
              'count': '${settings.bitTorrent.maxPeerConnections}',
            }),
          ),
        ],
      ),
    );
  }
}

class _NetworkPolicySection extends StatelessWidget {
  const _NetworkPolicySection({required this.policy});

  final BTPolicySettings policy;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final restricted = policy.restrictedCapabilitiesDisabled;
    final capabilities = <_Capability>[
      _Capability(
        L10nKeys.networkExplicitPeers.tr,
        policy.explicitPeersOnly,
        expectedEnabled: true,
      ),
      _Capability(L10nKeys.networkTrackers.tr, policy.trackersEnabled),
      _Capability(L10nKeys.networkDht.tr, policy.dhtEnabled),
      _Capability(L10nKeys.networkPex.tr, policy.pexEnabled),
      _Capability(L10nKeys.networkWebSeeds.tr, policy.webSeedsEnabled),
      _Capability(L10nKeys.networkIpv6.tr, policy.ipv6Enabled),
      _Capability(L10nKeys.networkInbound.tr, policy.inboundEnabled),
      _Capability(L10nKeys.networkUpload.tr, policy.uploadEnabled),
      _Capability(L10nKeys.networkSeeding.tr, policy.seedingEnabled),
    ];
    return _NetworkSection(
      key: const ValueKey('network-policy-section'),
      title: L10nKeys.networkPolicy.tr,
      subtitle: L10nKeys.networkPolicySubtitle.tr,
      trailing: Container(
        key: const ValueKey('network-policy-status'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: (restricted ? colors.success : colors.danger).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              restricted ? DownpeedIcons.shield : DownpeedIcons.issues,
              size: 14,
              color: restricted ? colors.success : colors.danger,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                restricted
                    ? L10nKeys.networkPolicyRestricted.tr
                    : L10nKeys.networkPolicyUnexpected.tr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: restricted ? colors.success : colors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 2 : 1;
          final width = constraints.maxWidth / columns;
          return Wrap(
            children: [
              for (var index = 0; index < capabilities.length; index++)
                SizedBox(
                  width: width,
                  child: _CapabilityRow(
                    capability: capabilities[index],
                    rightBorder: columns > 1 && index % columns != columns - 1,
                    bottomBorder: index < capabilities.length - columns,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

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
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Flexible(child: trailing!),
            ],
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
          child: child,
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.value,
    required this.rightBorder,
    required this.bottomBorder,
  });

  final _InfoValue value;
  final bool rightBorder;
  final bool bottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
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
          Text(
            value.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value.value,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkDetailRow extends StatelessWidget {
  const _NetworkDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: colors.textSecondary),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.capability,
    required this.rightBorder,
    required this.bottomBorder,
  });

  final _Capability capability;
  final bool rightBorder;
  final bool bottomBorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final expected = capability.enabled == capability.expectedEnabled;
    final statusColor = expected ? colors.success : colors.danger;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
      child: Row(
        children: [
          Icon(
            expected ? DownpeedIcons.locked : DownpeedIcons.issues,
            size: 15,
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              capability.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            capability.enabled
                ? L10nKeys.networkEnabled.tr
                : L10nKeys.networkDisabled.tr,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkMessage extends StatelessWidget {
  const _NetworkMessage({
    super.key,
    required this.titleKey,
    required this.bodyKey,
    this.loading = false,
    this.onRetry,
  });

  final String titleKey;
  final String bodyKey;
  final bool loading;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(DownpeedIcons.server, size: 24, color: colors.textMuted),
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

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    super.key,
    this.text,
    this.textKey,
    this.loading = false,
  });

  final String? text;
  final String? textKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(DownpeedIcons.info, size: 16, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ?? textKey?.tr ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoValue {
  const _InfoValue(this.label, this.value);

  final String label;
  final String value;
}

class _Capability {
  const _Capability(this.label, this.enabled, {this.expectedEnabled = false});

  final String label;
  final bool enabled;
  final bool expectedEnabled;
}
