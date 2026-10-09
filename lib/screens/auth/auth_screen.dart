import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/sync_provider.dart';
import '../settings/data_management_screen.dart';
import 'reset_password_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_buttons.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _minPasswordLength = 8;

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

    // อ่าน provider ทั้งหมดก่อน await: เมื่อ login สำเร็จ router จะ redirect ออกจาก
    // หน้านี้ทันที (State ถูก unmount) จึงใช้ context หลัง signIn ไม่ได้
    final authProvider = context.read<AuthProvider>();
    final syncProvider = context.read<SyncProvider>();
    final reloaders = <Future<void> Function()>[
      context.read<AccountProvider>().reload,
      context.read<CategoryProvider>().reload,
      context.read<TransactionProvider>().reload,
      context.read<BudgetProvider>().reload,
      context.read<RecurringTransactionProvider>().reload,
      context.read<CashFlowForecastProvider>().reload,
    ];
    final router = GoRouter.of(context);
    final isLoginMode = _isLogin;
    bool success;

    if (isLoginMode) {
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

    if (success && isLoginMode) {
      // Login สำเร็จ → reload providers แล้วค่อยกลับ (ทำต่อแม้หน้านี้ถูก unmount แล้ว)
      debugPrint('[AuthScreen] Login success, reloading providers...');

      // โหลดข้อมูลใหม่ตาม user ที่ login
      await syncProvider.initialize(
        () => Future.wait(reloaders.map((reload) => reload())),
      );

      debugPrint('[AuthScreen] Providers reloaded, navigating to home');
      router.go('/accounts');
    } else if (success && mounted) {
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _isLogin = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ'),
          backgroundColor: AppColors.income,
        ),
      );
    } else if (!success && mounted) {
      // Error จะแสดงผ่าน authProvider.error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'เกิดข้อผิดพลาด'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AuthScreen] build - rendering UI');
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
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
    final headerColor = AppColors.headerFor(
      isDarkMode,
      settingsProvider.themeColor,
    );
    final fabColor = AppColors.fabFor(isDarkMode, settingsProvider.themeColor);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: Text(
          _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDarkMode
                ? AppColors.darkTextPrimary
                : AppColors.textPrimary,
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: authProvider.isLoading,
        child: SafeArea(
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
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: fabColor,
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
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      border: Border.all(
                        color: AppColors.borderFor(isDarkMode),
                      ),
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
                              // บังคับความยาวเฉพาะตอนสมัคร เพื่อให้ผู้ใช้เดิมที่ตั้งรหัสสั้นกว่ายัง login ได้
                              if (!_isLogin &&
                                  value.length < _minPasswordLength) {
                                return 'รหัสผ่านต้องมีอย่างน้อย $_minPasswordLength ตัวอักษร';
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
                                labelStyle: TextStyle(
                                  color: secondaryTextColor,
                                ),
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
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _submit,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                  // Forgot Password (ส่งรหัส OTP ทางอีเมล แล้วตั้งรหัสใหม่ในแอป)
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DataManagementScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('สถานะฐานข้อมูล'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: secondaryTextColor,
                      side: BorderSide(
                        color: isDarkMode
                            ? AppColors.darkDivider
                            : AppColors.divider,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
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
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
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
}
