import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AuthCredentialsForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isLogin,
      isLoading,
      isDarkMode,
      obscurePassword,
      obscureConfirmPassword;
  final TextEditingController usernameController,
      emailController,
      passwordController,
      confirmPasswordController;
  final Color textColor,
      secondaryTextColor,
      accentColor,
      buttonColor,
      onButtonColor;
  final VoidCallback onSubmit, onTogglePassword, onToggleConfirmPassword;
  const AuthCredentialsForm({
    super.key,
    required this.formKey,
    required this.isLogin,
    required this.isLoading,
    required this.isDarkMode,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.buttonColor,
    required this.onButtonColor,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
  });
  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: formKey,
        child: Column(
          children: [
            Text(
              isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            // Username Field (เฉพาะตอนสมัคร)
            if (!isLogin) ...[
              TextFormField(
                controller: usernameController,
                autofillHints: const [AutofillHints.username],
                enabled: !isLoading,
                maxLength: 50,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  counterText: '',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: Icon(Icons.person, color: secondaryTextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อผู้ใช้';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            // Email Field
            TextFormField(
              controller: emailController,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'อีเมล',
                labelStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.email, color: secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกอีเมล';
                }
                if (!value.contains('@')) {
                  return 'กรุณากรอกอีเมลให้ถูกต้อง';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Password Field
            TextFormField(
              controller: passwordController,
              autofillHints: [
                isLogin ? AutofillHints.password : AutofillHints.newPassword,
              ],
              autocorrect: false,
              enableSuggestions: false,
              obscureText: obscurePassword,
              enabled: !isLoading,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'รหัสผ่าน',
                labelStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.lock, color: secondaryTextColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: secondaryTextColor,
                  ),
                  onPressed: () {
                    onTogglePassword();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกรหัสผ่าน';
                }
                // บังคับความยาวเฉพาะตอนสมัคร เพื่อให้ผู้ใช้เดิมที่ตั้งรหัสสั้นกว่ายัง login ได้
                if (!isLogin && value.length < 8) {
                  return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                }
                return null;
              },
            ),
            // Confirm Password (Register only)
            if (!isLogin) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                obscureText: obscureConfirmPassword,
                enabled: !isLoading,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: secondaryTextColor,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: secondaryTextColor,
                    ),
                    onPressed: () {
                      onToggleConfirmPassword();
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่าน';
                  }
                  if (value != passwordController.text) {
                    return 'รหัสผ่านไม่ตรงกัน';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: onButtonColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: buttonColor.withValues(alpha: 0.6),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            onButtonColor,
                          ),
                        ),
                      )
                    : Text(
                        isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
