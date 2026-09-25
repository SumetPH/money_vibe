import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Section title that sits outside (above) an [AppInsetCard].
class AppSectionHeader extends StatelessWidget {
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(20, 16, 20, 6);

  final String title;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader(
    this.title, {
    super.key,
    this.padding = defaultPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.textSecondaryFor(isDarkMode),
        ),
      ),
    );
  }
}

/// iOS inset-grouped card: surface fill, xLarge radius and a 1px border.
class AppInsetCard extends StatelessWidget {
  static const EdgeInsets defaultMargin = EdgeInsets.symmetric(horizontal: 16);

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;

  /// Hides the Material ink splash for rows that use their own pressed state.
  final bool disableSplash;

  const AppInsetCard({
    super.key,
    required this.children,
    this.margin = defaultMargin,
    this.padding,
    this.disableSplash = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDarkMode),
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    if (!disableSplash) return card;

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: card,
    );
  }
}

/// 1px divider between rows inside an [AppInsetCard].
class AppCardDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const AppCardDivider({super.key, this.indent = 0, this.endIndent = 0});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: AppColors.borderFor(isDarkMode),
    );
  }
}
