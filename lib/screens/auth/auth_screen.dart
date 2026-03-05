import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../theme/app_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[AuthScreen] initState - building auth screen');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isLogin) {
      success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      // Login/Register สำเร็จ → reload providers แล้วค่อยกลับ
      debugPrint('[AuthScreen] Login success, reloading providers...');
      
      // โหลดข้อมูลใหม่ตาม user ที่ login
      await Future.wait([
        context.read<AccountProvider>().reload(),
        context.read<CategoryProvider>().reload(),
        context.read<TransactionProvider>().reload(),
        context.read<BudgetProvider>().reload(),
        context.read<RecurringTransactionProvider>().reload(),
      ]);
      
      debugPrint('[AuthScreen] Providers reloaded, navigating back');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else if (!success && mounted) {
      // Error จะแสดงผ่าน authProvider.error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'เกิดข้อผิดพลาด'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AuthScreen] build - rendering UI');
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final authProvider = context.watch<AuthProvider>();

    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: textColor,
        title: Text(_isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 40,
                    color: isDarkMode
                        ? AppColors.darkFabYellow
                        : AppColors.fabYellow,
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  'Money Vibe',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                  style: TextStyle(fontSize: 18, color: secondaryTextColor),
                ),
                const SizedBox(height: 32),
                // Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !authProvider.isLoading,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'อีเมล',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            prefixIcon: Icon(
                              Icons.email,
                              color: secondaryTextColor,
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
                              borderSide: BorderSide(color: headerColor),
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
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !authProvider.isLoading,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: secondaryTextColor,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: secondaryTextColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
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
                              borderSide: BorderSide(color: headerColor),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            }
                            if (value.length < 6) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        // Confirm Password (Register only)
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            enabled: !authProvider.isLoading,
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
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: secondaryTextColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
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
                                borderSide: BorderSide(color: headerColor),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณายืนยันรหัสผ่าน';
                              }
                              if (value != _passwordController.text) {
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
                            onPressed: authProvider.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: headerColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: headerColor.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
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
                ),
                const SizedBox(height: 24),
                // Toggle Login/Register
                TextButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                            authProvider.clearError();
                          });
                        },
                  child: Text(
                    _isLogin
                        ? 'ยังไม่มีบัญชี? สมัครสมาชิก'
                        : 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.darkTransfer
                          : AppColors.transfer,
                    ),
                  ),
                ),
                // Forgot Password
                if (_isLogin)
                  TextButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _showForgotPasswordDialog(context),
                    child: Text(
                      'ลืมรหัสผ่าน?',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;

    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('รีเซ็ตรหัสผ่าน', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'กรุณากรอกอีเมลของคุณ เราจะส่งลิงก์สำหรับรีเซ็ตรหัสผ่านไปให้',
              style: TextStyle(color: secondaryTextColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกอีเมลให้ถูกต้อง'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final success = await context.read<AuthProvider>().resetPassword(
                email,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'ส่งลิงก์รีเซ็ตรหัสผ่านไปยัง $email แล้ว'
                          : 'ไม่สามารถส่งลิงก์ได้ กรุณาลองใหม่อีกครั้ง',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ส่งลิงก์'),
          ),
        ],
      ),
    );
  }
}
