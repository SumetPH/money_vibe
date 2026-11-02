import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import 'auth_brand_panel.dart';
import 'auth_google_button.dart';
import 'auth_credentials_form.dart';
import 'auth_signup_code_form.dart';
import 'auth_forgot_password_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../theme/app_brand.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _formMaxWidth = 480.0;
  static const _twoColumnMinWidth = 900.0;

  bool _isLogin = true;
  String? _signUpEmail;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
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
    _usernameController.dispose();
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
        username: _usernameController.text.trim(),
      );
    }

    if (success) TextInput.finishAutofillContext();
    if (success && authProvider.isLoggedIn) {
      // Login สำเร็จ → เริ่ม Initial Load ของ user นี้เบื้องหลังแล้วไปหน้าหลักทันที
      // หน้าหลักแสดง skeleton จนกว่าข้อมูลจะพร้อม
      debugPrint('[AuthScreen] Login success, starting initial load');
      syncProvider.initialize().catchError((Object error) {
        debugPrint('[AuthScreen] Initial load failed: $error');
      });

      router.go('/accounts');
    } else if (mounted &&
        (success || authProvider.emailNeedingConfirmation != null)) {
      final email = _emailController.text.trim();
      setState(() => _signUpEmail = email);
      if (!success) await authProvider.resendSignUpCode(email);
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
    final themeColor = settingsProvider.themeColor;
    final accentColor = AppColors.accentFor(isDarkMode, themeColor);
    final fabColor = AppColors.fabFor(isDarkMode, themeColor);
    final onFabColor = AppColors.onFabFor(isDarkMode, themeColor);

    // web จอกว้าง: 2 คอลัมน์ (แผงแบรนด์ซ้าย + ฟอร์มขวา) ไม่มี AppBar
    final isTwoColumn =
        kIsWeb && MediaQuery.sizeOf(context).width >= _twoColumnMinWidth;

    final formBody = AbsorbPointer(
      absorbing: authProvider.isLoading,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formMaxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isTwoColumn) ...[
                    // Logo/Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: fabColor,
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      ),
                      child: Icon(AppBrand.logo, size: 40, color: onFabColor),
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
                    const SizedBox(height: 32),
                  ],
                  // Form
                  Container(
                    padding: EdgeInsets.all(isTwoColumn ? 32 : 24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      border: Border.all(
                        color: AppColors.borderFor(isDarkMode),
                      ),
                    ),
                    child: _signUpEmail != null
                        ? AuthSignUpCodeForm(
                            email: _signUpEmail!,
                            isLoading: authProvider.isLoading,
                            error: authProvider.error,
                            onVerify: (code) async {
                              final auth = context.read<AuthProvider>();
                              if (await auth.verifySignUpCode(
                                _signUpEmail!,
                                code,
                              )) {
                                TextInput.finishAutofillContext();
                              }
                            },
                            onResend: () =>
                                authProvider.resendSignUpCode(_signUpEmail!),
                            onBack: () => setState(() {
                              _signUpEmail = null;
                              authProvider.clearError();
                            }),
                          )
                        : Column(
                            children: [
                              AuthCredentialsForm(
                                formKey: _formKey,
                                isLogin: _isLogin,
                                isLoading: authProvider.isLoading,
                                isDarkMode: isDarkMode,
                                obscurePassword: _obscurePassword,
                                obscureConfirmPassword: _obscureConfirmPassword,
                                usernameController: _usernameController,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                                accentColor: accentColor,
                                buttonColor: fabColor,
                                onButtonColor: onFabColor,
                                onSubmit: _submit,
                                onTogglePassword: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onToggleConfirmPassword: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                              if (authProvider.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    authProvider.error!,
                                    style: TextStyle(
                                      color: AppColors.expenseFor(isDarkMode),
                                    ),
                                  ),
                                ),
                              if (authProvider.isGoogleAvailable)
                                AuthGoogleButton(
                                  isLoading: authProvider.isLoading,
                                  isDarkMode: isDarkMode,
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final success = await authProvider
                                        .signInWithGoogle();
                                    if (!success &&
                                        authProvider.error != null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(authProvider.error!),
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
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
                    child: Text.rich(
                      TextSpan(
                        text: _isLogin
                            ? 'ยังไม่มีบัญชี? '
                            : 'มีบัญชีอยู่แล้ว? ',
                        style: TextStyle(color: secondaryTextColor),
                        children: [
                          TextSpan(
                            text: _isLogin ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Forgot Password (ส่งรหัส OTP ทางอีเมล แล้วตั้งรหัสใหม่ในแอป)
                  if (_isLogin)
                    TextButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => showAuthForgotPasswordDialog(
                              context,
                              _emailController.text.trim(),
                            ),
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
      ),
    );

    if (isTwoColumn) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: AuthBrandPanel(
                isDarkMode: isDarkMode,
                accentColor: accentColor,
                fabColor: fabColor,
                onFabColor: onFabColor,
              ),
            ),
            Expanded(flex: 4, child: formBody),
          ],
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
      body: formBody,
    );
  }
}
