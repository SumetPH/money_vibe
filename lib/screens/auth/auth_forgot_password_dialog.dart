import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import 'reset_password_screen.dart';

void showAuthForgotPasswordDialog(BuildContext context, String email) {
  final settingsProvider = context.read<SettingsProvider>();
  final isDarkMode = settingsProvider.isDarkMode;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryTextColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final headerColor = AppColors.headerFor(
    isDarkMode,
    settingsProvider.themeColor,
  );

  // เติมอีเมลจากหน้า login ไว้ให้ ผู้ใช้จะได้ไม่ต้องพิมพ์ซ้ำ
  final emailController = TextEditingController(text: email);
  var isSending = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Future<void> sendCode() async {
          final email = emailController.text.trim();
          if (email.isEmpty || !email.contains('@')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กรุณากรอกอีเมลให้ถูกต้อง'),
                backgroundColor: AppColors.expense,
              ),
            );
            return;
          }

          final authProvider = context.read<AuthProvider>();
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          setDialogState(() => isSending = true);
          final success = await authProvider.resetPassword(email);
          if (!ctx.mounted) return;

          if (!success) {
            // ส่งไม่สำเร็จ: คง dialog ไว้ให้ลองใหม่ได้
            setDialogState(() => isSending = false);
            messenger.showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'ส่งรหัสไม่สำเร็จ'),
                backgroundColor: AppColors.expense,
              ),
            );
            return;
          }

          Navigator.pop(ctx);
          messenger.showSnackBar(
            SnackBar(
              content: Text('ส่งรหัสยืนยันไปยัง $email แล้ว'),
              backgroundColor: AppColors.income,
            ),
          );
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(email: email),
            ),
          );
        }

        // design-check: allow input or multi-choice dialog
        return AlertDialog(
          backgroundColor: surfaceColor,
          title: Text('รีเซ็ตรหัสผ่าน', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'กรุณากรอกอีเมลของคุณ เราจะส่งรหัสยืนยันสำหรับตั้งรหัสผ่านใหม่ไปให้',
                style: TextStyle(color: secondaryTextColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                enabled: !isSending,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'อีเมล',
                  hintStyle: TextStyle(color: secondaryTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: isSending ? null : sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: headerColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: headerColor.withValues(alpha: 0.6),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('ส่งรหัส'),
            ),
          ],
        );
      },
    ),
  );
}
