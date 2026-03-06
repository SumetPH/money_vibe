import 'package:flutter/material.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
import 'auth_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTesting = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) {
    var normalized = url.trim();
    if (normalized.isEmpty) return normalized;
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> _testConnection() async {
    final url = _normalizeUrl(_urlController.text);
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอก URL และ API Key';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    final dbManager = DatabaseManager();
    final success = await dbManager.testSupabaseConnectionWithCredentials(
      url: url,
      anonKey: key,
    );

    setState(() {
      _isTesting = false;
      _errorMessage = success ? 'เชื่อมต่อสำเร็จ!' : 'เชื่อมต่อไม่สำเร็จ';
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อ Supabase สำเร็จ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    final url = _normalizeUrl(_urlController.text);
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอก URL และ API Key';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final dbManager = DatabaseManager();
    final success = await dbManager.configureSupabase(url: url, anonKey: key);

    setState(() {
      _isSaving = false;
    });

    if (success && mounted) {
      // ไปหน้า Login
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    } else {
      setState(() {
        _errorMessage = 'ไม่สามารถบันทึกการตั้งค่าได้';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo/Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.header,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Center(
                child: Text(
                  'ยินดีต้อนรับ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Money Vibe',
                  style: TextStyle(fontSize: 20, color: secondaryTextColor),
                ),
              ),
              const SizedBox(height: 48),
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: AppColors.header),
                        const SizedBox(width: 8),
                        Text(
                          'ตั้งค่า Supabase',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'แอพนี้ใช้ Supabase เป็นฐานข้อมูลบน Cloud\n'
                      'ข้อมูลของคุณจะถูกซิงค์และเข้าถึงได้จากทุกอุปกรณ์',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supabase URL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'https://your-project.supabase.co',
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withAlpha(128),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Anon Key',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        hintText: 'your-anon-key',
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withAlpha(128),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                      obscureText: true,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _errorMessage == 'เชื่อมต่อสำเร็จ!'
                              ? AppColors.income
                              : AppColors.expense,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check, size: 18),
                          label: const Text('ทดสอบ'),
                        ),
                        SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveAndContinue,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('บันทึกและเข้าสู่ระบบ'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.header,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Help text
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('วิธีการตั้งค่า Supabase'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
