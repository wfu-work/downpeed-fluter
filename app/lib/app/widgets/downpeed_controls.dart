import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../configs/theme/downpeed_icons.dart';
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
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final controlHeight = math.max(
      DownpeedThemeTokens.controlHeight,
      MediaQuery.textScalerOf(context).scale(14) + 14,
    );
    return Opacity(
      opacity: onSelected == null ? 0.5 : 1,
      child: Container(
        constraints: BoxConstraints(minHeight: controlHeight),
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
                onPressed: onSelected == null
                    ? null
                    : () => onSelected?.call(segments[index].value),
              ),
              if (index != segments.length - 1)
                VerticalDivider(width: 1, thickness: 1, color: colors.border),
            ],
          ],
        ),
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
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
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final enabled = onChanged != null;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      onTap: enabled ? () => onChanged?.call(!value) : null,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.46,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => onChanged?.call(!value) : null,
              borderRadius: BorderRadius.circular(
                DownpeedThemeTokens.radiusPill,
              ),
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
      ),
    );
  }
}

class DownpeedNumberStepper extends StatelessWidget {
  const DownpeedNumberStepper({
    super.key,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    required this.decrementTooltip,
    required this.incrementTooltip,
    this.decrementKey,
    this.incrementKey,
  });

  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int>? onChanged;
  final String decrementTooltip;
  final String incrementTooltip;
  final Key? decrementKey;
  final Key? incrementKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final height = math.max(
      DownpeedThemeTokens.controlHeight,
      MediaQuery.textScalerOf(context).scale(14) + 14,
    );
    final enabled = onChanged != null;
    return Semantics(
      value: '$value',
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.46,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(color: colors.borderStrong),
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                key: decrementKey,
                icon: DownpeedIcons.minus,
                tooltip: decrementTooltip,
                onPressed: enabled && value > minimum
                    ? () => onChanged?.call(value - 1)
                    : null,
                height: height,
              ),
              VerticalDivider(width: 1, thickness: 1, color: colors.border),
              SizedBox(
                width: 44,
                child: Text(
                  '$value',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: colors.border),
              _StepperButton(
                key: incrementKey,
                icon: DownpeedIcons.add,
                tooltip: incrementTooltip,
                onPressed: enabled && value < maximum
                    ? () => onChanged?.call(value + 1)
                    : null,
                height: height,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.height,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(width: height, height: height),
    iconSize: 14,
    icon: Icon(icon),
  );
}

class DownpeedMenuOption<T> {
  const DownpeedMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

class DownpeedMenuControl<T> extends StatelessWidget {
  const DownpeedMenuControl({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.tooltip,
  });

  final T value;
  final List<DownpeedMenuOption<T>> options;
  final ValueChanged<T>? onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final selected = options.firstWhere((option) => option.value == value);
    final height = math.max(
      DownpeedThemeTokens.controlHeight,
      MediaQuery.textScalerOf(context).scale(14) + 14,
    );
    return Opacity(
      opacity: onSelected == null ? 0.46 : 1,
      child: PopupMenuButton<T>(
        enabled: onSelected != null,
        tooltip: tooltip,
        initialValue: value,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<T>(value: option.value, child: Text(option.label)),
        ],
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 132, maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(color: colors.borderStrong),
            borderRadius: BorderRadius.circular(DownpeedThemeTokens.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(DownpeedIcons.expand, size: 14, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
