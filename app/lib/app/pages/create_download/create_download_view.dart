import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../configs/localization/l10n_keys.dart';
import '../../../configs/theme/downpeed_icons.dart';
import '../../../configs/theme/downpeed_theme_tokens.dart';
import '../../../data/clients/engine_client.dart';
import '../../../domains/bt_resolution.dart';
import '../../../domains/download_resolution.dart';
import '../../../domains/download_task.dart';
import '../../../services/directory_picker.dart';
import '../../../services/engine_settings_service.dart';
import '../../../services/torrent_file_picker.dart';
import '../../widgets/transfer_track.dart';
import 'create_download_controller.dart';

Future<void> showCreateDownloadDialog({String initialUrl = ''}) async {
  final context = Get.context;
  if (context == null) return;

  final controller = CreateDownloadController(
    client: Get.find<EngineClient>(),
    directoryPicker: Get.find<DirectoryPicker>(),
    engineSettingsService: Get.find<EngineSettingsService>(),
    torrentFilePicker: Get.find<TorrentFilePicker>(),
    initialUrl: initialUrl,
  )..onInit();
  final dark = Theme.of(context).brightness == Brightness.dark;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: dark ? 0.38 : 0.16),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (context) => CreateDownloadDialog(controller: controller),
    );
  } finally {
    controller.onClose();
  }
}

class CreateDownloadView extends GetView<CreateDownloadController> {
  const CreateDownloadView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Scaffold(
      backgroundColor: colors.workspace,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CreateHeader(),
            Expanded(
              child: _CreateDownloadContent(
                controller: controller,
                showEyebrow: true,
                wideTopPadding: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateDownloadDialog extends StatelessWidget {
  const CreateDownloadDialog({required this.controller, super.key});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final compact = size.width < 640;
        final horizontalInset = compact ? 8.0 : 32.0;
        final verticalInset = compact ? 8.0 : 32.0;
        final colors = context.downpeedColors;

        return Obx(() {
          final isEntryPhase =
              controller.phase.value == CreateDownloadPhase.idle;
          final maxWidth = size.width - horizontalInset * 2;
          final maxHeight = compact
              ? size.height - verticalInset * 2
              : math.min(760.0, size.height * 0.88);
          final width = compact
              ? maxWidth
              : math.min(isEntryPhase ? 720.0 : 820.0, maxWidth);
          final desktopHeight = isEntryPhase ? 424.0 : 760.0;
          final height = compact
              ? maxHeight
              : math.min(desktopHeight, maxHeight);
          final animationDuration = MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180);

          return PopScope(
            canPop: !controller.isBusy,
            child: Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: verticalInset,
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 18,
              shadowColor: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.46
                    : 0.16,
              ),
              child: AnimatedContainer(
                key: const ValueKey('create-download-dialog'),
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        compact ? 8 : 9,
                        8,
                        compact ? 8 : 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        border: Border(
                          bottom: BorderSide(color: colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(
                                DownpeedThemeTokens.radius,
                              ),
                              border: Border.all(color: colors.border),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(DownpeedIcons.download),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  L10nKeys.tasksAdd.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  'HTTP / HTTPS / TORRENT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          SizedBox.square(
                            key: const ValueKey('close-create-download-dialog'),
                            dimension: compact
                                ? 44
                                : DownpeedThemeTokens.touchTarget,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              onPressed: controller.isBusy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(DownpeedIcons.close),
                              style: IconButton.styleFrom(
                                fixedSize: Size.square(
                                  compact
                                      ? 44
                                      : DownpeedThemeTokens.touchTarget,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: colors.workspace,
                        child: _CreateDownloadContent(
                          controller: controller,
                          showEyebrow: false,
                          wideTopPadding: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class _CreateDownloadContent extends StatelessWidget {
  const _CreateDownloadContent({
    required this.controller,
    required this.showEyebrow,
    required this.wideTopPadding,
  });

  final CreateDownloadController controller;
  final bool showEyebrow;
  final double wideTopPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return SingleChildScrollView(
          key: const ValueKey('create-download-scroll-view'),
          padding: EdgeInsets.fromLTRB(
            compact
                ? DownpeedThemeTokens.compactPagePadding
                : DownpeedThemeTokens.pagePadding,
            compact ? 20 : wideTopPadding,
            compact
                ? DownpeedThemeTokens.compactPagePadding
                : DownpeedThemeTokens.pagePadding,
            compact ? 28 : 30,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CreateIntro(showEyebrow: showEyebrow),
                  SizedBox(height: compact ? 20 : 22),
                  _URLForm(controller: controller),
                  const SizedBox(height: 12),
                  _AdvancedOptions(controller: controller),
                  SizedBox(height: compact ? 16 : 18),
                  Obx(
                    () => switch (controller.phase.value) {
                      CreateDownloadPhase.idle => const _IdleHint(),
                      CreateDownloadPhase.resolving => const _ResolvingPanel(),
                      CreateDownloadPhase.resolved =>
                        controller.hasBTResolution
                            ? _BTResolutionPanel(controller: controller)
                            : controller.isBatchMode
                            ? _BatchResolutionPanel(controller: controller)
                            : _ResolutionPanel(
                                resolution: controller.resolution.value!,
                                controller: controller,
                              ),
                      CreateDownloadPhase.creating =>
                        const _CreatingTaskPanel(),
                      CreateDownloadPhase.batchCreated => _BatchTaskResultPanel(
                        controller: controller,
                      ),
                      CreateDownloadPhase.queued ||
                      CreateDownloadPhase.downloading ||
                      CreateDownloadPhase.retrying ||
                      CreateDownloadPhase.paused ||
                      CreateDownloadPhase.completed ||
                      CreateDownloadPhase.canceled => _TaskPanel(
                        controller: controller,
                        task: controller.task.value!,
                      ),
                      CreateDownloadPhase.failed =>
                        controller.task.value == null
                            ? _FailurePanel(
                                message:
                                    controller.errorMessage.value ??
                                    L10nKeys.createResolveError.tr,
                              )
                            : _TaskPanel(
                                controller: controller,
                                task: controller.task.value!,
                              ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreateIntro extends StatelessWidget {
  const _CreateIntro({required this.showEyebrow});

  final bool showEyebrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Row(
      key: const ValueKey('create-download-intro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.surfaceSubtle,
            borderRadius: BorderRadius.circular(
              DownpeedThemeTokens.radiusLarge,
            ),
            border: Border.all(color: colors.border),
          ),
          alignment: Alignment.center,
          child: Icon(DownpeedIcons.link, color: colors.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showEyebrow) ...[
                Text(
                  L10nKeys.createEyebrow.tr.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                L10nKeys.createTitle.tr,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                L10nKeys.createSubtitle.tr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateHeader extends StatelessWidget {
  const _CreateHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('create-back-button'),
            tooltip: L10nKeys.createBack.tr,
            onPressed: Get.back,
            icon: const Icon(DownpeedIcons.back),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              L10nKeys.createBack.tr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(
                DownpeedThemeTokens.radiusPill,
              ),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'M2 · 03',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _URLForm extends StatelessWidget {
  const _URLForm({required this.controller});

  static const _collapsedControlHeight = 40.0;

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('download-url-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
              final stack = constraints.maxWidth < 460 || largeText;
              final label = Text(
                L10nKeys.createUrlLabel.tr,
                style: Theme.of(context).textTheme.labelLarge,
              );
              final protocols = Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radiusPill,
                  ),
                ),
                child: Text(
                  'HTTP · HTTPS · MAGNET',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [label, const SizedBox(height: 7), protocols],
                );
              }
              return Row(
                children: [
                  Expanded(child: label),
                  Flexible(child: protocols),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final input = TextField(
                key: const ValueKey('download-url-field'),
                controller: controller.urlController,
                focusNode: controller.urlFocusNode,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 6,
                minLines: 1,
                decoration: InputDecoration(
                  hint: Text(
                    L10nKeys.createUrlHint.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  prefixIcon: const Icon(DownpeedIcons.link),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: _collapsedControlHeight,
                    minHeight: _collapsedControlHeight,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  fillColor: colors.workspace,
                ),
              );
              final action = Obx(
                () => FilledButton.icon(
                  key: const ValueKey('resolve-download-button'),
                  onPressed:
                      controller.hasInput.value && !controller.isResolving
                      ? controller.resolve
                      : null,
                  icon: controller.isResolving
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : const Icon(DownpeedIcons.search),
                  label: Text(
                    controller.isResolving
                        ? L10nKeys.createResolving.tr
                        : L10nKeys.createResolve.tr,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 10),
                    SizedBox(height: _collapsedControlHeight, child: action),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 132,
                    height: _collapsedControlHeight,
                    child: action,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({required this.controller});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const ValueKey('advanced-options'),
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 13),
          childrenPadding: const EdgeInsets.fromLTRB(40, 0, 14, 14),
          iconColor: colors.textSecondary,
          collapsedIconColor: colors.textMuted,
          leading: const Icon(DownpeedIcons.server),
          title: Text(
            L10nKeys.createAdvanced.tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                L10nKeys.createAdvancedBody.tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final picker = OutlinedButton.icon(
                  key: const ValueKey('choose-torrent-file-button'),
                  onPressed: controller.isBusy
                      ? null
                      : controller.chooseTorrentFile,
                  icon: const Icon(DownpeedIcons.torrentFile),
                  label: Text(L10nKeys.createBTChooseTorrent.tr),
                );
                return Align(
                  alignment: Alignment.centerLeft,
                  child: constraints.maxWidth < 420
                      ? SizedBox(width: double.infinity, child: picker)
                      : picker,
                );
              },
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                L10nKeys.createBTPickerHint.tr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('create-download-idle-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(DownpeedIcons.info, color: colors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              L10nKeys.createIdleHint.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvingPanel extends StatefulWidget {
  const _ResolvingPanel();

  @override
  State<_ResolvingPanel> createState() => _ResolvingPanelState();
}

class _ResolvingPanelState extends State<_ResolvingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    lowerBound: 0.18,
    upperBound: 0.78,
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _animation
        ..stop()
        ..value = 0.48;
    } else {
      _animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      liveRegion: true,
      label: L10nKeys.createResolving.tr,
      child: Container(
        key: const ValueKey('resolve-progress-panel'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => TransferTrack(
                progress: _reduceMotion == true ? 0.48 : _animation.value,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              L10nKeys.createResolving.tr,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              L10nKeys.createResolvingBody.tr,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('resolve-error-panel'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.07),
          border: Border.all(color: colors.danger.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(DownpeedIcons.issues, size: 16, color: colors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10nKeys.createFailedTitle.tr,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: colors.danger),
                  ),
                  const SizedBox(height: 5),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionPanel extends StatelessWidget {
  const _ResolutionPanel({required this.resolution, required this.controller});

  final DownloadResolution resolution;
  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('resolve-success-panel'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    DownpeedIcons.completed,
                    size: 16,
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nKeys.createResolvedTitle.tr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        L10nKeys.createResolvedBody.tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  L10nKeys.createFileName.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 7),
                SelectableText(
                  resolution.fileName,
                  key: const ValueKey('resolved-file-name'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(height: 1.25),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    final itemWidth = wide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 18,
                      children: [
                        _MetadataItem(
                          width: itemWidth,
                          icon: DownpeedIcons.server,
                          label: L10nKeys.createSourceHost.tr,
                          value: resolution.finalHost.isEmpty
                              ? L10nKeys.createUnknown.tr
                              : resolution.finalHost,
                        ),
                        _MetadataItem(
                          width: itemWidth,
                          icon: DownpeedIcons.database,
                          label: L10nKeys.createFileSize.tr,
                          value: _formatDownloadBytes(resolution.size),
                        ),
                        _MetadataItem(
                          width: itemWidth,
                          icon: DownpeedIcons.file,
                          label: L10nKeys.createContentType.tr,
                          value: resolution.contentType.isEmpty
                              ? L10nKeys.createUnknown.tr
                              : resolution.contentType,
                        ),
                        _MetadataItem(
                          width: itemWidth,
                          icon: DownpeedIcons.download,
                          label: L10nKeys.createRange.tr,
                          value: resolution.acceptRanges
                              ? L10nKeys.createRangeYes.tr
                              : L10nKeys.createRangeNo.tr,
                          valueColor: resolution.acceptRanges
                              ? colors.success
                              : colors.warning,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _TaskCreationControls(
            controller: controller,
            fileName: resolution.fileName,
          ),
        ],
      ),
    );
  }
}

class _BTResolutionPanel extends StatelessWidget {
  const _BTResolutionPanel({required this.controller});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final resolution = controller.btResolution.value!;
      final colors = context.downpeedColors;
      final magnet = resolution.sourceType == BTSourceType.magnet;
      return Container(
        key: const ValueKey('bt-resolution-panel'),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        DownpeedThemeTokens.radius,
                      ),
                    ),
                    child: Icon(
                      magnet ? DownpeedIcons.magnet : DownpeedIcons.torrentFile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          magnet
                              ? L10nKeys.createBTMagnetTitle.tr
                              : L10nKeys.createBTResolvedTitle.tr,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          magnet
                              ? L10nKeys.createBTMagnetBody.tr
                              : L10nKeys.createBTResolvedBody.tr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textSecondary,
                                height: 1.42,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    resolution.name,
                    key: const ValueKey('bt-resolution-name'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _BTMetadataLine(
                    icon: DownpeedIcons.database,
                    label: L10nKeys.createBTInfoHash.tr,
                    value: _truncateHash(resolution.displayHash),
                  ),
                  _BTMetadataLine(
                    icon: DownpeedIcons.server,
                    label: L10nKeys.createBTTrackers.tr,
                    value: resolution.trackers.isEmpty
                        ? '—'
                        : resolution.trackers
                              .map((tracker) => tracker.displayValue)
                              .join(' · '),
                  ),
                  if (!magnet)
                    _BTMetadataLine(
                      icon: DownpeedIcons.info,
                      label: L10nKeys.createBTPrivacy.tr,
                      value: resolution.isPrivate
                          ? L10nKeys.createBTPrivate.tr
                          : L10nKeys.createBTPublic.tr,
                      last: true,
                    ),
                ],
              ),
            ),
            if (resolution.files.isNotEmpty) ...[
              Divider(height: 1, color: colors.border),
              _BTFileSelection(controller: controller, resolution: resolution),
            ],
            if (!magnet) ...[
              Divider(height: 1, color: colors.border),
              _BTTaskCreationControls(
                controller: controller,
                resolution: resolution,
              ),
            ],
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
              color: colors.surfaceSubtle,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(DownpeedIcons.info, color: colors.textMuted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      (magnet
                              ? L10nKeys.createBTMagnetParsingOnly
                              : L10nKeys.createBTRestrictedTransfer)
                          .tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _BTFileSelection extends StatelessWidget {
  const _BTFileSelection({required this.controller, required this.resolution});

  final CreateDownloadController controller;
  final BTResolution resolution;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final colors = context.downpeedColors;
      final selected = controller.selectedBTFileIndexes;
      final selectedCount = controller.selectedBTFileCount;
      final selectedSize = controller.selectedBTSize;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            child: Row(
              children: [
                Checkbox(
                  key: const ValueKey('select-all-bt-files'),
                  value: controller.allBTFilesSelected
                      ? true
                      : selected.isEmpty
                      ? false
                      : null,
                  tristate: true,
                  onChanged: (_) => controller.toggleAllBTFiles(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nKeys.createBTFiles.tr,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        L10nKeys.createBTSelectedSummary.trParams({
                          'selected': '$selectedCount',
                          'total': '${resolution.files.length}',
                          'size': _formatDownloadBytes(selectedSize),
                        }),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: controller.toggleAllBTFiles,
                  child: Text(L10nKeys.createBTSelectAll.tr),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 292),
            child: ListView.builder(
              key: const ValueKey('bt-file-list'),
              shrinkWrap: true,
              itemExtent: 48,
              itemCount: resolution.files.length,
              itemBuilder: (context, index) {
                final file = resolution.files[index];
                return InkWell(
                  key: ValueKey('bt-file-${file.index}'),
                  onTap: () => controller.toggleBTFile(file.index),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Row(
                      children: [
                        Checkbox(
                          key: ValueKey('bt-file-checkbox-${file.index}'),
                          value: selected.contains(file.index),
                          onChanged: (_) => controller.toggleBTFile(file.index),
                        ),
                        const SizedBox(width: 5),
                        const Icon(DownpeedIcons.file),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            file.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDownloadBytes(file.size),
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
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _BTMetadataLine extends StatelessWidget {
  const _BTMetadataLine({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.textMuted),
          const SizedBox(width: 9),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BTTaskCreationControls extends StatelessWidget {
  const _BTTaskCreationControls({
    required this.controller,
    required this.resolution,
  });

  final CreateDownloadController controller;
  final BTResolution resolution;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Obx(() {
      final directory = controller.saveDirectory.value;
      final hasExplicitPeers = controller.explicitPeersInput.value.isNotEmpty;
      final peerError = controller.peerInputError.value;
      final actionError = controller.actionError.value;
      final canCreateTask = hasExplicitPeers && controller.canCreateBTTask;
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L10nKeys.createSaveDirectory.tr,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final path = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        DownpeedIcons.folder,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        directory?.isNotEmpty == true
                            ? directory!
                            : L10nKeys.createDirectoryRequired.tr,
                        key: const ValueKey('bt-selected-save-directory'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: directory?.isNotEmpty == true
                              ? colors.text
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                );
                final picker = OutlinedButton.icon(
                  key: const ValueKey('bt-choose-save-directory-button'),
                  onPressed: controller.isPickingDirectory.value
                      ? null
                      : controller.chooseSaveDirectory,
                  icon: const Icon(DownpeedIcons.folder),
                  label: Text(
                    directory?.isNotEmpty == true
                        ? L10nKeys.createChangeDirectory.tr
                        : L10nKeys.createChooseDirectory.tr,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [path, const SizedBox(height: 10), picker],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: path),
                    const SizedBox(width: 14),
                    picker,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              L10nKeys.createBTPeers.tr,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 5),
            Text(
              L10nKeys.createBTPeersBody.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              key: const ValueKey('bt-explicit-peers-field'),
              controller: controller.explicitPeersController,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: L10nKeys.createBTPeersHint.tr,
                prefixIcon: const Icon(DownpeedIcons.connections),
                alignLabelWithHint: true,
                errorText: peerError,
                fillColor: colors.workspace,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(DownpeedIcons.shield, color: colors.textMuted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      L10nKeys.createBTSecurityNotice.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (actionError != null && actionError != peerError) ...[
              const SizedBox(height: 11),
              _InlineError(message: actionError),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 15),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final destination = Text(
                  directory?.isNotEmpty == true
                      ? '$directory/${resolution.name}'
                      : resolution.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                );
                final action = FilledButton.icon(
                  key: const ValueKey('start-bt-download-button'),
                  onPressed: canCreateTask ? controller.createBTTask : null,
                  icon: const Icon(DownpeedIcons.download),
                  label: Text(L10nKeys.createBTStart.tr),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [destination, const SizedBox(height: 11), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: destination),
                    const SizedBox(width: 14),
                    action,
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

String _truncateHash(String value) {
  if (value.length <= 24) return value;
  return '${value.substring(0, 12)}…${value.substring(value.length - 10)}';
}

String _formatDownloadBytes(int bytes) {
  if (bytes < 0) return L10nKeys.createUnknown.tr;
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

class _BatchResolutionPanel extends StatelessWidget {
  const _BatchResolutionPanel({required this.controller});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final resolutions = controller.resolutions;
    final failures = controller.resolveFailures;
    return Container(
      key: const ValueKey('batch-resolve-success-panel'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(DownpeedIcons.completed, size: 16, color: colors.success),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nKeys.createBatchResolvedTitle.trParams({
                          'count': '${resolutions.length}',
                        }),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        L10nKeys.createBatchResolvedBody.tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          for (var index = 0; index < resolutions.length; index++) ...[
            _BatchResolutionRow(index: index, resolution: resolutions[index]),
            if (index < resolutions.length - 1)
              Divider(height: 1, indent: 54, color: colors.border),
          ],
          if (failures.isNotEmpty) ...[
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
              child: Text(
                L10nKeys.createBatchResolveFailed.trParams({
                  'count': '${failures.length}',
                }),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.danger),
              ),
            ),
            for (final failure in failures)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                child: _BatchFailureRow(
                  title: failure.url,
                  message: failure.message,
                ),
              ),
          ],
          _TaskCreationControls(
            controller: controller,
            fileName: resolutions.first.fileName,
            fileCount: resolutions.length,
          ),
        ],
      ),
    );
  }
}

class _BatchResolutionRow extends StatelessWidget {
  const _BatchResolutionRow({required this.index, required this.resolution});

  final int index;
  final DownloadResolution resolution;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Padding(
      key: ValueKey('resolved-batch-file-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(DownpeedIcons.file, color: colors.textMuted),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolution.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${resolution.finalHost.isEmpty ? L10nKeys.createUnknown.tr : resolution.finalHost} · ${_formatResolutionSize(resolution.size)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${index + 1}'.padLeft(2, '0'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchFailureRow extends StatelessWidget {
  const _BatchFailureRow({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(DownpeedIcons.issues, size: 15, color: colors.danger),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskCreationControls extends StatelessWidget {
  const _TaskCreationControls({
    required this.controller,
    required this.fileName,
    this.fileCount = 1,
  });

  final CreateDownloadController controller;
  final String fileName;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DownpeedThemeTokens.radiusLarge),
        ),
      ),
      child: Obx(() {
        final directory = controller.saveDirectory.value;
        final actionError = controller.actionError.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L10nKeys.createSaveDirectory.tr,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 9),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final path = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        DownpeedIcons.folder,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        directory?.isNotEmpty == true
                            ? directory!
                            : L10nKeys.createDirectoryRequired.tr,
                        key: const ValueKey('selected-save-directory'),
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: directory?.isNotEmpty == true
                              ? colors.text
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                );
                final picker = OutlinedButton.icon(
                  key: const ValueKey('choose-save-directory-button'),
                  onPressed: controller.isPickingDirectory.value
                      ? null
                      : controller.chooseSaveDirectory,
                  icon: const Icon(DownpeedIcons.folder),
                  label: Text(
                    directory?.isNotEmpty == true
                        ? L10nKeys.createChangeDirectory.tr
                        : L10nKeys.createChooseDirectory.tr,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [path, const SizedBox(height: 12), picker],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: path),
                    const SizedBox(width: 14),
                    picker,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _ScheduleControls(controller: controller),
            if (actionError != null) ...[
              const SizedBox(height: 11),
              _InlineError(message: actionError),
            ],
            const SizedBox(height: 18),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final destination = Text(
                  fileCount > 1
                      ? L10nKeys.createBatchDestination.trParams({
                          'count': '$fileCount',
                        })
                      : directory?.isNotEmpty == true
                      ? '$directory/$fileName'
                      : fileName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                );
                final action = FilledButton.icon(
                  key: const ValueKey('start-download-button'),
                  onPressed: controller.canCreateTask
                      ? controller.createTask
                      : null,
                  icon: const Icon(DownpeedIcons.download),
                  label: Text(
                    fileCount > 1
                        ? L10nKeys.createStartBatch.trParams({
                            'count': '$fileCount',
                          })
                        : L10nKeys.createStartDownload.tr,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [destination, const SizedBox(height: 12), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: destination),
                    const SizedBox(width: 14),
                    action,
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }
}

class _ScheduleControls extends StatelessWidget {
  const _ScheduleControls({required this.controller});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Obx(() {
      final selected = controller.scheduledAt.value?.toLocal();
      final value = selected == null
          ? L10nKeys.createScheduleNow.tr
          : DateFormat('yyyy-MM-dd HH:mm').format(selected);
      return Container(
        key: const ValueKey('download-schedule-controls'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surfaceRaised.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('choose-schedule-button'),
                  onPressed: () => _chooseSchedule(context),
                  icon: const Icon(DownpeedIcons.clock),
                  label: Text(L10nKeys.createScheduleChoose.tr),
                ),
                if (selected != null)
                  TextButton.icon(
                    key: const ValueKey('clear-schedule-button'),
                    onPressed: () => controller.setScheduledAt(null),
                    icon: const Icon(DownpeedIcons.close),
                    label: Text(L10nKeys.createScheduleClear.tr),
                  ),
              ],
            );
            final summary = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(DownpeedIcons.clock, color: colors.textMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nKeys.createSchedule.tr,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected == null
                              ? colors.textSecondary
                              : colors.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        L10nKeys.createScheduleBody.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 10), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: 14),
                actions,
              ],
            );
          },
        ),
      );
    });
  }

  Future<void> _chooseSchedule(BuildContext context) async {
    final now = DateTime.now();
    final selected = controller.scheduledAt.value?.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = selected == null
        ? today
        : DateTime(selected.year, selected.month, selected.day);
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDay.isBefore(today) ? today : selectedDay,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: selected == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5)))
          : TimeOfDay.fromDateTime(selected),
    );
    if (time == null) return;
    controller.setScheduledAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _CreatingTaskPanel extends StatelessWidget {
  const _CreatingTaskPanel();

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      key: const ValueKey('creating-task-panel'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10nKeys.createCreating.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  L10nKeys.createCreatingBody.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchTaskResultPanel extends StatelessWidget {
  const _BatchTaskResultPanel({required this.controller});

  final CreateDownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final result = controller.batchResult.value!;
    final failures = controller.batchCreationFailures;
    return Container(
      key: const ValueKey('batch-created-panel'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.succeeded > 0
                      ? DownpeedIcons.completed
                      : DownpeedIcons.issues,
                  color: result.succeeded > 0 ? colors.success : colors.danger,
                  size: 17,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10nKeys.createBatchCreatedTitle.tr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        L10nKeys.createBatchCreatedBody.tr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        L10nKeys.createBatchCreatedSummary.trParams({
                          'succeeded': '${result.succeeded}',
                          'failed': '${result.failed}',
                        }),
                        key: const ValueKey('batch-created-summary'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: result.failed == 0
                              ? colors.success
                              : colors.warning,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (failures.isNotEmpty) ...[
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                L10nKeys.createBatchFailuresTitle.tr,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.danger),
              ),
            ),
            for (final failure in failures)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                child: _BatchFailureRow(
                  title: failure.fileName,
                  message: failure.message,
                ),
              ),
          ],
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('batch-back-to-tasks-button'),
                onPressed: Get.back,
                icon: const Icon(DownpeedIcons.back),
                label: Text(L10nKeys.createBack.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({required this.controller, required this.task});

  final CreateDownloadController controller;
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final (title, body, statusColor, statusIcon) = switch (task.state) {
      DownloadTaskState.queued => (
        L10nKeys.taskQueued.tr,
        L10nKeys.taskQueuedBody.tr,
        colors.textSecondary,
        DownpeedIcons.clock,
      ),
      DownloadTaskState.downloading => (
        L10nKeys.taskDownloading.tr,
        L10nKeys.taskDownloadingBody.tr,
        colors.accent,
        DownpeedIcons.download,
      ),
      DownloadTaskState.retrying => (
        L10nKeys.taskRetrying.tr,
        L10nKeys.taskRetryingBody.tr,
        colors.warning,
        DownpeedIcons.retry,
      ),
      DownloadTaskState.paused => (
        L10nKeys.taskPaused.tr,
        L10nKeys.taskPausedBody.tr,
        colors.warning,
        DownpeedIcons.pause,
      ),
      DownloadTaskState.completed => (
        L10nKeys.taskCompleted.tr,
        L10nKeys.taskCompletedBody.tr,
        colors.success,
        DownpeedIcons.completed,
      ),
      DownloadTaskState.canceled => (
        L10nKeys.taskCanceled.tr,
        L10nKeys.taskCanceledBody.tr,
        colors.textMuted,
        DownpeedIcons.stop,
      ),
      DownloadTaskState.failed => (
        L10nKeys.taskFailed.tr,
        L10nKeys.taskFailedBody.tr,
        colors.danger,
        DownpeedIcons.issues,
      ),
    };
    final statusBody = task.hasFutureSchedule
        ? L10nKeys.taskScheduledBody.trParams({
            'time': DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(task.scheduledAt!.toLocal()),
          })
        : body;
    final progress = task.total > 0
        ? task.progress
        : task.state == DownloadTaskState.completed
        ? 1.0
        : 0.34;
    final progressText = task.total > 0
        ? '${_formatByteCount(task.downloaded)} / ${_formatByteCount(task.total)}'
        : L10nKeys.taskUnknownTotal.trParams({
            'downloaded': _formatByteCount(task.downloaded),
          });

    return Container(
      key: const ValueKey('active-download-panel'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, color: statusColor, size: 17),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  task.fileName,
                  key: const ValueKey('active-download-file-name'),
                  softWrap: true,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(height: 1.3),
                ),
                const SizedBox(height: 18),
                TransferTrack(progress: progress),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 520;
                    final width = wide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MetadataItem(
                          width: width,
                          icon: DownpeedIcons.database,
                          label: L10nKeys.taskProgress.tr,
                          value: progressText,
                          valueColor: statusColor,
                        ),
                        if (task.protocol == DownloadProtocol.bt)
                          _MetadataItem(
                            width: width,
                            icon: DownpeedIcons.connections,
                            label: L10nKeys.taskConnections.tr,
                            value: '${task.connections}',
                          ),
                        _MetadataItem(
                          width: width,
                          icon: DownpeedIcons.download,
                          label: L10nKeys.taskSpeed.tr,
                          value: task.state == DownloadTaskState.downloading
                              ? '${_formatByteCount(task.speedBps)}/s'
                              : '—',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  L10nKeys.taskDestination.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  task.filePath,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (task.state == DownloadTaskState.failed) ...[
                  const SizedBox(height: 15),
                  _InlineError(message: controller.taskFailureMessage),
                ],
                Obx(() {
                  final actionError = controller.actionError.value;
                  if (actionError == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: _InlineError(message: actionError),
                  );
                }),
                if (task.canPause || task.canResume || task.canCancel) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Obx(
                      () => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (task.canPause)
                            OutlinedButton.icon(
                              key: const ValueKey('pause-download-button'),
                              onPressed: controller.isUpdatingTask.value
                                  ? null
                                  : controller.pauseTask,
                              icon: const Icon(DownpeedIcons.pause),
                              label: Text(L10nKeys.taskPause.tr),
                            ),
                          if (task.canResume)
                            FilledButton.tonalIcon(
                              key: const ValueKey('resume-download-button'),
                              onPressed: controller.isUpdatingTask.value
                                  ? null
                                  : controller.resumeTask,
                              icon: const Icon(DownpeedIcons.resume),
                              label: Text(L10nKeys.taskResume.tr),
                            ),
                          if (task.canCancel)
                            OutlinedButton.icon(
                              key: const ValueKey('cancel-download-button'),
                              onPressed: controller.isCanceling.value
                                  ? null
                                  : controller.cancelTask,
                              icon: const Icon(DownpeedIcons.stop),
                              label: Text(
                                controller.isCanceling.value
                                    ? L10nKeys.taskCanceling.tr
                                    : L10nKeys.taskCancel.tr,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(DownpeedIcons.issues, size: 15, color: colors.danger),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.danger, height: 1.4),
          ),
        ),
      ],
    );
  }
}

String _formatByteCount(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String _formatResolutionSize(int bytes) {
  if (bytes < 0) return L10nKeys.createUnknown.tr;
  return _formatByteCount(bytes);
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: colors.textMuted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
