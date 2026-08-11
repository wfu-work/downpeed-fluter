import 'package:flutter/material.dart';

import '../../configs/theme/downpeed_theme_tokens.dart';

class DownpeedSegment<T> {
  const DownpeedSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class DownpeedSegmentedControl<T> extends StatelessWidget {
  const DownpeedSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  final List<DownpeedSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Container(
      height: DownpeedThemeTokens.controlHeight,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.borderStrong),
        borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            _SegmentButton<T>(
              segment: segments[index],
              selected: segments[index].value == selected,
              onPressed: () => onSelected(segments[index].value),
            ),
            if (index != segments.length - 1)
              VerticalDivider(width: 1, thickness: 1, color: colors.border),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onPressed,
  });

  final DownpeedSegment<T> segment;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.sidebarSelection : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: colors.surfaceSubtle,
          focusColor: colors.surfaceSubtle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DownpeedThemeTokens.controlHeight - 2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 14,
                      color: selected ? colors.text : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    segment.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? colors.text : colors.textSecondary,
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

class DownpeedSwitch extends StatelessWidget {
  const DownpeedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      button: true,
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radiusPill),
            hoverColor: colors.sidebarSelection,
            focusColor: colors.sidebarSelection,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: 30,
                height: 18,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value ? colors.accent : colors.surfaceSubtle,
                  border: Border.all(
                    color: value ? colors.accent : colors.borderStrong,
                  ),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radiusPill,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: value ? colors.onAccent : colors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
