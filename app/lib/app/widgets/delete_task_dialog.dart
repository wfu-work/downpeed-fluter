import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/localization/l10n_keys.dart';
import '../../configs/theme/downpeed_icons.dart';
import '../../configs/theme/downpeed_theme_tokens.dart';

Future<bool?> showDeleteTaskDialog({
  required int taskCount,
  bool allowDeleteFiles = false,
  bool clearCompleted = false,
}) async {
  final context = Get.context;
  if (context == null || taskCount <= 0) return null;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: dark ? 0.38 : 0.16),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (context) => _DeleteTaskDialog(
      taskCount: taskCount,
      allowDeleteFiles: allowDeleteFiles && !clearCompleted,
      clearCompleted: clearCompleted,
    ),
  );
}

class _DeleteTaskDialog extends StatefulWidget {
  const _DeleteTaskDialog({
    required this.taskCount,
    required this.allowDeleteFiles,
    required this.clearCompleted,
  });

  final int taskCount;
  final bool allowDeleteFiles;
  final bool clearCompleted;

  @override
  State<_DeleteTaskDialog> createState() => _DeleteTaskDialogState();
}

class _DeleteTaskDialogState extends State<_DeleteTaskDialog> {
  bool _deleteFiles = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.downpeedColors;
    final media = MediaQuery.of(context);
    final horizontalInset = media.size.width < 520 ? 12.0 : 32.0;
    final maxWidth = math.min(440.0, media.size.width - horizontalInset * 2);
    final title = widget.clearCompleted
        ? L10nKeys.tasksClearCompletedTitle.tr
        : widget.taskCount == 1
        ? L10nKeys.tasksDeleteTitle.tr
        : L10nKeys.tasksDeleteBatchTitle.trParams({
            'count': '${widget.taskCount}',
          });
    final body = widget.clearCompleted
        ? L10nKeys.tasksClearCompletedBody.trParams({
            'count': '${widget.taskCount}',
          })
        : widget.taskCount == 1
        ? L10nKeys.tasksDeleteBody.tr
        : L10nKeys.tasksDeleteBatchBody.trParams({
            'count': '${widget.taskCount}',
          });

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset),
      clipBehavior: Clip.antiAlias,
      elevation: 18,
      shadowColor: Colors.black.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.46 : 0.16,
      ),
      child: ConstrainedBox(
        key: const ValueKey('delete-task-dialog'),
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: media.size.height - 24,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DownpeedThemeTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        DownpeedThemeTokens.radius,
                      ),
                    ),
                    child: Icon(
                      DownpeedIcons.delete,
                      size: DownpeedThemeTokens.iconSize,
                      color: colors.danger,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.allowDeleteFiles) ...[
                const SizedBox(height: 18),
                InkWell(
                  key: const ValueKey('delete-downloaded-files-option'),
                  borderRadius: BorderRadius.circular(
                    DownpeedThemeTokens.radius,
                  ),
                  onTap: () => setState(() => _deleteFiles = !_deleteFiles),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        DownpeedThemeTokens.radius,
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: const ValueKey('delete-files-checkbox'),
                          value: _deleteFiles,
                          onChanged: (value) =>
                              setState(() => _deleteFiles = value ?? false),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10nKeys.tasksDeleteFiles.tr,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                L10nKeys.tasksDeleteFilesDescription.tr,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('cancel-delete-task'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('confirm-delete-task'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(_deleteFiles),
                    icon: const Icon(DownpeedIcons.delete),
                    label: Text(
                      widget.clearCompleted
                          ? L10nKeys.tasksClearCompletedConfirm.tr
                          : L10nKeys.tasksDeleteConfirm.tr,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
