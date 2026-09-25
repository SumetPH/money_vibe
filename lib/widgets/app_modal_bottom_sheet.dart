import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  Color? backgroundColor,
}) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    backgroundColor:
        backgroundColor ??
        (isDarkMode ? AppColors.darkSurface : AppColors.surface),
    barrierColor: Colors.black.withValues(alpha: 0.5),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.xLarge),
      ),
    ),
    builder: builder,
  );
}

class AppModalBottomSheetHeader extends StatelessWidget {
  final String title;

  const AppModalBottomSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );
  }
}

/// Full-height, draggable body for selection sheets with long lists. Use it
/// as the builder result of [showAppModalBottomSheet] with
/// `isScrollControlled: true`, and attach [ScrollController] to the list.
class AppDraggableSheet extends StatelessWidget {
  static const double _minChildSize = 0.3;
  static const double _maxChildSize = 1.0;

  final ScrollableWidgetBuilder builder;

  const AppDraggableSheet({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _maxChildSize,
      minChildSize: _minChildSize,
      maxChildSize: _maxChildSize,
      expand: false,
      builder: builder,
    );
  }
}
