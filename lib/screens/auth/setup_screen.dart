import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbManager = context.watch<DatabaseManager>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.expense.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.cloud_off_outlined,
                            color: AppColors.expense,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ยังไม่พบค่า Supabase ของ build นี้',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'แอปต้องถูก build พร้อมค่า APP_ENV, SUPABASE_URL และ SUPABASE_ANON_KEY จากไฟล์ config/dev.json หรือ config/prod.json',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    if (dbManager.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dbManager.error!,
                          style: TextStyle(
                            color: AppColors.expense,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: dbManager.isLoading
                            ? null
                            : () => dbManager.init(),
                        icon: dbManager.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('ตรวจสอบอีกครั้ง'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
