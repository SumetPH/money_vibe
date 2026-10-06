import 'package:flutter/material.dart';
import '../../theme/app_radii.dart';

Widget buildCategoryNameFieldRow({
  required TextEditingController controller,
  required Color surfaceColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(
            Icons.edit_note_rounded,
            color: textSecondaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            'ชื่อ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: 'กรอกชื่อหมวดหมู่',
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.6),
                fontSize: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: () => controller.clear(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.cancel_rounded,
                color: textSecondaryColor.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget buildCategoryPickerRow({
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
  required Color surfaceColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.xLarge),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: textSecondaryColor,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

Widget buildCategoryNoteField({
  required TextEditingController controller,
  required Color surfaceColor,
  required Color textPrimaryColor,
  required Color textSecondaryColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(
              Icons.notes_rounded,
              color: textSecondaryColor,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: 'บันทึกช่วยจำ (ไม่บังคับ)',
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.6),
                fontSize: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
        ),
      ],
    ),
  );
}
