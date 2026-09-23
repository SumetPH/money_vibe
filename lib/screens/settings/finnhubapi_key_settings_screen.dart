import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class FinnhubApiKeySettingsScreen extends StatefulWidget {
  const FinnhubApiKeySettingsScreen({super.key});

  @override
  State<FinnhubApiKeySettingsScreen> createState() =>
      _FinnhubApiKeySettingsScreenState();
}

class _FinnhubApiKeySettingsScreenState
    extends State<FinnhubApiKeySettingsScreen> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  bool _isConfigured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsProvider>();
    _controller.text = settings.finnhubApiKey ?? '';
    _isConfigured = settings.isFinnhubConfigured;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final settings = context.read<SettingsProvider>();
    final apiKey = _controller.text.trim();

    await settings.setFinnhubApiKey(apiKey.isEmpty ? null : apiKey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiKey.isEmpty ? 'ลบ API key แล้ว' : 'บันทึก API key แล้ว',
          ),
          backgroundColor: apiKey.isEmpty ? Colors.orange : AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Material(
            color: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.full),
              side: BorderSide(
                color: isDarkMode
                    ? AppColors.darkDivider.withValues(alpha: 0.4)
                    : AppColors.divider.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Finnhub API Key',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xLarge),
                  side: BorderSide(color: dividerColor.withValues(alpha: 0.4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status indicator
                      Row(
                        children: [
                          Icon(
                            _isConfigured ? Icons.check_circle : Icons.warning,
                            color: _isConfigured ? incomeColor : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isConfigured
                                ? 'API Key ตั้งค่าแล้ว'
                                : 'ยังไม่ได้ตั้งค่า API Key',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isConfigured
                                  ? incomeColor
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // API Key input field
                      TextField(
                        controller: _controller,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'Finnhub API Key',
                          hintText: 'ใส่ API key ของคุณ',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscureText = !_obscureText);
                            },
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                        ),
                        autofocus: !_isConfigured,
                      ),
                      const SizedBox(height: 16),

                      // Helper text
                      const Text(
                        'API key จะถูกเก็บในเครื่องของคุณอย่างปลอดภัย',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      FilledButton.icon(
                        onPressed: _saveApiKey,
                        icon: const Icon(Icons.save),
                        label: const Text('บันทึก'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Clear button (only show if configured)
                      if (_isConfigured)
                        OutlinedButton.icon(
                          onPressed: () {
                            _controller.clear();
                            _saveApiKey();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('ลบ API Key'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: expenseColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
