import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class LLMApiKeySettingsScreen extends StatefulWidget {
  const LLMApiKeySettingsScreen({super.key});

  @override
  State<LLMApiKeySettingsScreen> createState() =>
      _LLMApiKeySettingsScreenState();
}

class _LLMApiKeySettingsScreenState extends State<LLMApiKeySettingsScreen> {
  bool _obscureText = true;
  bool _isConfigured = false;

  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsProvider>();
    _apiKeyController.text = settings.llmApiKey ?? '';
    _baseUrlController.text = settings.llmBaseUrl ?? '';
    _modelController.text = settings.llmModel ?? '';
    _isConfigured = settings.isFinnhubConfigured;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final settings = context.read<SettingsProvider>();
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();

    await settings.setLLM(
      apiKey.isEmpty ? null : apiKey,
      baseUrl.isEmpty ? null : baseUrl,
      model.isEmpty ? null : model,
    );

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
      appBar: AppBar(title: const Text('LLM API Key')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
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
                              color: _isConfigured
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // API Key input field
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'API Key',
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

                      TextField(
                        controller: _baseUrlController,
                        decoration: InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'ใส่ Base URL ของคุณ',
                          prefixIcon: const Icon(Icons.link),
                          border: const OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _modelController,
                        decoration: InputDecoration(
                          labelText: 'Model',
                          hintText: 'ใส่ Model ของคุณ',
                          prefixIcon: const Icon(Icons.model_training),
                          border: const OutlineInputBorder(),
                          filled: true,
                        ),
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
                            _apiKeyController.clear();
                            _baseUrlController.clear();
                            _modelController.clear();
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
