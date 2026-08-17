import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../domains/engine_info.dart';
import '../../../domains/engine_settings.dart';
import '../../widgets/downpeed_app_shell.dart';
import '../../widgets/task_display.dart';
import 'network_controller.dart';

const _networkPageMaxWidth = 1440.0;
const _networkCardBorderAlpha = 0.56;
const _networkDividerAlpha = 0.34;

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
          constraints: const BoxConstraints(maxWidth: _networkPageMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10nKeys.networkTitle.tr,
                    key: const ValueKey('network-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: DownpeedThemeTokens.textHeading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    L10nKeys.networkSubtitle.tr,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    key: const ValueKey('network-refresh'),
                    tooltip: L10nKeys.networkRefresh.tr,
                    onPressed: () => unawaited(controller.refresh()),
                    icon: const Icon(DownpeedIcons.retry),
                  ),
                  IconButton(
                    key: const ValueKey('network-open-settings'),
                    tooltip: L10nKeys.networkOpenSettings.tr,
                    onPressed: controller.openSettings,
                    icon: const Icon(DownpeedIcons.settings),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 10),
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
        ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > _networkPageMaxWidth
                  ? _networkPageMaxWidth
                  : constraints.maxWidth;
              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (engineState == EngineConnectionState.checking &&
                          info == null)
                        const _NetworkMessage(
                          key: ValueKey('network-loading'),
                          loading: true,
                          titleKey: L10nKeys.networkLoading,
                          bodyKey: L10nKeys.networkEngineSubtitle,
                        )
                      else if (engineState == EngineConnectionState.offline &&
                          info == null)
                        _NetworkMessage(
                          key: const ValueKey('network-offline'),
                          titleKey: L10nKeys.engineOfflineTitle,
                          bodyKey: L10nKeys.networkUnavailable,
                          onRetry: controller.refresh,
                        )
                      else ...[
                        if (info != null) _EngineSection(info: info),
                        if (info != null) const SizedBox(height: 18),
                        if (settings != null) ...[
                          _SchedulerSection(settings: settings.scheduler),
                          const SizedBox(height: 18),
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
                          const SizedBox(height: 18),
                          _NetworkPolicySection(policy: settings.bitTorrent),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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
          Divider(
            height: 1,
            indent: 48,
            color: context.downpeedColors.border.withValues(
              alpha: _networkDividerAlpha,
            ),
          ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final compact = constraints.maxWidth < 620 || textScale >= 1.6;
            final heading = Column(
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
            );
            if (compact && trailing != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: trailing!),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: trailing!),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 11),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(
              color: colors.border.withValues(alpha: _networkCardBorderAlpha),
            ),
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
              ? BorderSide(
                  color: colors.border.withValues(alpha: _networkDividerAlpha),
                )
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(
                  color: colors.border.withValues(alpha: _networkDividerAlpha),
                )
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final compact = constraints.maxWidth < 520 || textScale >= 1.6;
          final iconWidget = Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: colors.textSecondary),
          );
          final labelWidget = Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          );
          final valueWidget = SelectableText(
            value,
            textAlign: compact ? TextAlign.left : TextAlign.right,
            maxLines: compact ? 3 : 2,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w500,
            ),
          );
          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelWidget,
                      const SizedBox(height: 4),
                      valueWidget,
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconWidget,
              const SizedBox(width: 16),
              SizedBox(width: 170, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
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
              ? BorderSide(
                  color: colors.border.withValues(alpha: _networkDividerAlpha),
                )
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(
                  color: colors.border.withValues(alpha: _networkDividerAlpha),
                )
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
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: colors.surfaceRaised.withValues(alpha: 0.72),
          border: Border.all(
            color: colors.border.withValues(alpha: _networkCardBorderAlpha),
          ),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
        ),
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
        color: colors.surfaceRaised.withValues(alpha: 0.72),
        border: Border.all(
          color: colors.border.withValues(alpha: _networkCardBorderAlpha),
        ),
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
