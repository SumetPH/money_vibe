import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AuthSignUpCodeForm extends StatefulWidget {
  final String email;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onVerify;
  final Future<bool> Function() onResend;
  final VoidCallback onBack;

  const AuthSignUpCodeForm({
    super.key,
    required this.email,
    required this.isLoading,
    required this.error,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  State<AuthSignUpCodeForm> createState() => _AuthSignUpCodeFormState();
}

class _AuthSignUpCodeFormState extends State<AuthSignUpCodeForm> {
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ยืนยันอีเมล', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('กรอกรหัสยืนยันที่ส่งไปยัง ${widget.email}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _code,
            enabled: !widget.isLoading,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'รหัสยืนยัน'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'กรุณากรอกรหัสยืนยัน'
                : null,
            onFieldSubmitted: (_) => _verify(),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.error!,
                style: TextStyle(
                  color: AppColors.expenseFor(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.isLoading ? null : _verify,
            child: Text(widget.isLoading ? 'กำลังตรวจสอบ…' : 'ยืนยันอีเมล'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.isLoading || _seconds > 0
                ? null
                : () async {
                    final success = await widget.onResend();
                    if (!context.mounted) return;
                    setState(() => _seconds = 60);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ส่งรหัสยืนยันใหม่แล้ว')),
                      );
                    }
                  },
            child: Text(
              _seconds > 0 ? 'ขอรหัสใหม่ใน $_seconds วินาที' : 'ขอรหัสใหม่',
            ),
          ),
          TextButton(
            onPressed: widget.isLoading ? null : widget.onBack,
            child: const Text('กลับไปเข้าสู่ระบบ'),
          ),
        ],
      ),
    ),
  );

  void _verify() {
    if (!widget.isLoading && _formKey.currentState!.validate()) {
      widget.onVerify(_code.text.trim());
    }
  }
}
