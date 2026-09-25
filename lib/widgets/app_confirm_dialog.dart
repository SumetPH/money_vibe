import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Shows the app's confirmation dialog. Resolves to `true` only when the user
/// taps the confirm action; cancel, barrier tap and back all resolve `false`.
/// Pass either a plain [message] or a custom [content] widget.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String confirmLabel = 'ยืนยัน',
  String cancelLabel = 'ยกเลิก',
  bool isDestructive = false,
}) async {
  assert(
    (message == null) != (content == null),
    'Provide exactly one of message or content',
  );
  final settings = context.read<SettingsProvider>();
  final isDarkMode = settings.isDarkMode;
  final textColor = AppColors.textPrimaryFor(isDarkMode);
  final confirmColor = isDestructive
      ? AppColors.expenseFor(isDarkMode)
      : AppColors.accentFor(isDarkMode, settings.themeColor);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceFor(isDarkMode),
      title: Text(title, style: TextStyle(color: textColor)),
      content: content ?? Text(message!, style: TextStyle(color: textColor)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel, style: TextStyle(color: textColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
