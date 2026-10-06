import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_buttons.dart';

/// ตั้งรหัสผ่านใหม่ด้วยรหัส OTP ที่ส่งไปทางอีเมล (ไม่ต้องใช้ deep link)
class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _minPasswordLength = 8;
  // Supabase ตั้งความยาว OTP ได้ 6–10 หลัก (ค่าเริ่มต้น 6)
  static const _minCodeLength = 6;
  static const _maxCodeLength = 10;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;

    final isReset = await authProvider.resetPasswordWithCode(
      email: widget.email,
      code: _codeController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!isReset) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ'),
          backgroundColor: AppColors.expenseFor(isDarkMode),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Text('ตั้งรหัสผ่านใหม่แล้ว กรุณาเข้าสู่ระบบ'),
        backgroundColor: AppColors.incomeFor(isDarkMode),
      ),
    );
    if (mounted) navigator.pop();
  }

  Future<void> _resendCode() async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;

    final isSent = await authProvider.resetPassword(widget.email);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isSent
              ? 'ส่งรหัสใหม่ไปยัง ${widget.email} แล้ว'
              : authProvider.error ?? 'ส่งรหัสไม่สำเร็จ',
        ),
        backgroundColor: isSent
            ? AppColors.incomeFor(isDarkMode)
            : AppColors.expenseFor(isDarkMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final isLoading = context.watch<AuthProvider>().isLoading;
    final backgroundColor = AppColors.backgroundFor(isDarkMode);
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);
    final headerColor = AppColors.headerFor(
      isDarkMode,
      settingsProvider.themeColor,
    );

    InputDecoration decoration(String label, IconData icon, {Widget? suffix}) {
      final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderFor(isDarkMode)),
      );
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: Icon(icon, color: secondaryTextColor),
        suffixIcon: suffix,
        counterText: '',
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: headerColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: const AppBackButton(),
        title: Text(
          'ตั้งรหัสผ่านใหม่',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(isDarkMode),
                borderRadius: BorderRadius.circular(AppRadii.xLarge),
                border: Border.all(color: AppColors.borderFor(isDarkMode)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'กรอกรหัสยืนยันที่ส่งไปยัง ${widget.email} '
                      'แล้วตั้งรหัสผ่านใหม่',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: _maxCodeLength,
                      style: TextStyle(color: textColor, letterSpacing: 4),
                      decoration: decoration('รหัสยืนยัน', Icons.pin_outlined),
                      validator: (value) {
                        final code = value?.trim() ?? '';
                        if (code.length < _minCodeLength) {
                          return 'กรุณากรอกรหัสยืนยันจากอีเมล';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      style: TextStyle(color: textColor),
                      decoration: decoration(
                        'รหัสผ่านใหม่',
                        Icons.lock,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: secondaryTextColor,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < _minPasswordLength) {
                          return 'รหัสผ่านต้องมีอย่างน้อย $_minPasswordLength ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: textColor),
                      decoration: decoration(
                        'ยืนยันรหัสผ่านใหม่',
                        Icons.lock_outline,
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'รหัสผ่านไม่ตรงกัน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: AppColors.onHeader,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onHeader,
                                ),
                              )
                            : const Text(
                                'ตั้งรหัสผ่านใหม่',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isLoading ? null : _resendCode,
                      child: Text(
                        'ไม่ได้รับรหัส? ส่งอีกครั้ง',
                        style: TextStyle(color: secondaryTextColor),
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
