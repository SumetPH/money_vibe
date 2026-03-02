import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class ApiKeySettingsScreen extends StatefulWidget {
  const ApiKeySettingsScreen({super.key});

  @override
  State<ApiKeySettingsScreen> createState() => _ApiKeySettingsScreenState();
}

class _ApiKeySettingsScreenState extends State<ApiKeySettingsScreen> {
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
          backgroundColor: apiKey.isEmpty ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finnhub API Key')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'วิธีรับ API Key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. เข้าเว็บไซต์ ',
                      style: TextStyle(fontSize: 14),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'เปิด https://finnhub.io ในเบราว์เซอร์',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'https://finnhub.io',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '2. สมัครสมาชิก (ฟรี ไม่ต้องใส่บัตรเครดิต)',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '3. ไปที่ Dashboard > API Copy เพื่อ copy API key',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status indicator
            Row(
              children: [
                Icon(
                  _isConfigured ? Icons.check_circle : Icons.warning,
                  color: _isConfigured ? Colors.green : Colors.orange,
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
                    color: _isConfigured ? Colors.green : Colors.orange,
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
                    _obscureText ? Icons.visibility : Icons.visibility_off,
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
                  foregroundColor: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
