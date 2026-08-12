import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/localization/l10n_keys.dart';
import '../../configs/theme/downpeed_theme_tokens.dart';
import '../../domains/engine_info.dart';
import '../../services/engine_service.dart';

class EngineStatusBadge extends StatelessWidget {
  const EngineStatusBadge({super.key, this.compact = false, this.dense = false})
    : assert(!compact || !dense);

  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final engine = EngineService.to;
    return Obx(() {
      final state = engine.state.value;
      final colors = context.downpeedColors;
      final (label, color) = switch (state) {
        EngineConnectionState.checking => (
          L10nKeys.engineChecking.tr,
          colors.warning,
        ),
        EngineConnectionState.online => (
          L10nKeys.engineOnline.tr,
          colors.success,
        ),
        EngineConnectionState.offline => (
          L10nKeys.engineOffline.tr,
          colors.danger,
        ),
      };
      return Semantics(
        label: label,
        liveRegion: true,
        child: Tooltip(
          message: label,
          child: Container(
            key: const ValueKey('engine-status-badge'),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 4 : 8,
              vertical: compact
                  ? 10
                  : dense
                  ? 2
                  : 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: compact ? 8 : 6,
                  height: compact ? 8 : 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style:
                        (dense
                                ? Theme.of(context).textTheme.labelSmall
                                : Theme.of(context).textTheme.labelMedium)
                            ?.copyWith(
                              color: dense
                                  ? colors.textMuted
                                  : colors.textSecondary,
                            ),
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
