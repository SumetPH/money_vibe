import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'app_form_row.dart';
import 'app_modal_bottom_sheet.dart';

/// ขนาดกล่อง preview ท้ายแถว icon/color picker
const pickerPreviewSize = 36.0;
const _previewIconSize = 20.0;
const _previewTintAlpha = 0.15;

const _iconGridColumns = 5;
const _colorGridColumns = 4;
const _gridSpacing = 12.0;
const _iconSize = 24.0;
const _selectedBorderWidth = 2.0;
const _selectedColorBorderWidth = 2.5;

/// Sheet เลือกไอคอนจาก [AppColors.accountIcons]; คืน null เมื่อปิดโดยไม่เลือก
Future<IconData?> showIconPickerSheet({
  required BuildContext context,
  required String title,
  required IconData selectedIcon,
  required Color accentColor,
}) {
  return showAppModalBottomSheet<IconData>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickerGridSheet(
      title: title,
      columns: _iconGridColumns,
      itemCount: AppColors.accountIcons.length,
      itemBuilder: (context, isDarkMode, i) {
        final icon = AppColors.accountIcons[i];
        final isSelected = icon == selectedIcon;
        return _PickerTile(
          fillColor: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : AppColors.insetFillFor(isDarkMode),
          border: isSelected
              ? BorderSide(color: accentColor, width: _selectedBorderWidth)
              : BorderSide(color: AppColors.borderFor(isDarkMode)),
          onTap: () => Navigator.pop(context, icon),
          child: Icon(
            icon,
            color: isSelected
                ? accentColor
                : AppColors.textSecondaryFor(isDarkMode),
            size: _iconSize,
          ),
        );
      },
    ),
  );
}

/// Sheet เลือกสีจาก [AppColors.accountColors]; คืน null เมื่อปิดโดยไม่เลือก
Future<Color?> showColorPickerSheet({
  required BuildContext context,
  required String title,
  required Color selectedColor,
}) {
  return showAppModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickerGridSheet(
      title: title,
      columns: _colorGridColumns,
      itemCount: AppColors.accountColors.length,
      itemBuilder: (context, isDarkMode, i) {
        final color = AppColors.accountColors[i];
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        return _PickerTile(
          fillColor: color,
          // ขอบสีข้อความหลักให้ตัดกับทั้งพื้น sheet และสีของช่อง
          border: isSelected
              ? BorderSide(
                  color: AppColors.textPrimaryFor(isDarkMode),
                  width: _selectedColorBorderWidth,
                )
              : BorderSide.none,
          onTap: () => Navigator.pop(context, color),
          child: isSelected
              ? ColoredBox(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: _iconSize,
                    ),
                  ),
                )
              : null,
        );
      },
    ),
  );
}

/// แถวฟอร์มที่เปิด [showIconPickerSheet]; [preview] ใช้แทนไอคอน เช่นรูปที่อัปโหลด
class IconPickerFormRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? preview;

  const IconPickerFormRow({
    super.key,
    this.label = 'ไอคอน',
    required this.icon,
    required this.color,
    required this.onTap,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return AppFormRow(
      icon: Icons.category_outlined,
      label: label,
      onTap: onTap,
      trailing: _PickerRowTrailing(
        preview: preview ?? IconPickerPreview(icon: icon, color: color),
      ),
    );
  }
}

/// แถวฟอร์มที่เปิด [showColorPickerSheet]
class ColorPickerFormRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ColorPickerFormRow({
    super.key,
    this.label = 'สี',
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppFormRow(
      icon: Icons.color_lens_outlined,
      label: label,
      onTap: onTap,
      trailing: _PickerRowTrailing(preview: PickerPreviewBox(color: color)),
    );
  }
}

/// ไอคอนบนพื้นสีจาง ขนาดเท่า preview ของแถว picker
class IconPickerPreview extends StatelessWidget {
  final IconData icon;
  final Color color;

  const IconPickerPreview({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return PickerPreviewBox(
      color: color.withValues(alpha: _previewTintAlpha),
      child: Icon(icon, color: color, size: _previewIconSize),
    );
  }
}

/// กล่องมุมมน [pickerPreviewSize] สำหรับ preview ท้ายแถว picker
class PickerPreviewBox extends StatelessWidget {
  final Color color;
  final Widget? child;

  const PickerPreviewBox({super.key, required this.color, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: pickerPreviewSize,
      height: pickerPreviewSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: child,
    );
  }
}

class _PickerRowTrailing extends StatelessWidget {
  final Widget preview;

  const _PickerRowTrailing({required this.preview});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        preview,
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondaryFor(isDarkMode),
          size: 20,
        ),
      ],
    );
  }
}

typedef _PickerItemBuilder =
    Widget Function(BuildContext context, bool isDarkMode, int index);

class _PickerGridSheet extends StatelessWidget {
  final String title;
  final int columns;
  final int itemCount;
  final _PickerItemBuilder itemBuilder;

  const _PickerGridSheet({
    required this.title,
    required this.columns,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return AppDraggableSheet(
      builder: (_, scrollController) => Column(
        children: [
          AppModalBottomSheetHeader(title: title),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _gridSpacing,
                crossAxisSpacing: _gridSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (context, i) => itemBuilder(context, isDarkMode, i),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final Color fillColor;
  final BorderSide border;
  final VoidCallback onTap;
  final Widget? child;

  const _PickerTile({
    required this.fillColor,
    required this.border,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fillColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
