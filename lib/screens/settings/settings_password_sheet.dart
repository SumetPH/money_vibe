import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

Future<void> showSettingsPasswordSheet(BuildContext context) =>
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const SettingsPasswordSheet(),
    );

class SettingsPasswordSheet extends StatefulWidget {
  const SettingsPasswordSheet({super.key});
  @override
  State<SettingsPasswordSheet> createState() => _SettingsPasswordSheetState();
}

class _SettingsPasswordSheetState extends State<SettingsPasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nonce = TextEditingController();
  bool _showNonce = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_current, _password, _confirm, _nonce]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = auth.hasPassword
        ? await auth.changePassword(_current.text, _password.text)
        : await auth.setPassword(
            _password.text,
            nonce: _showNonce ? _nonce.text.trim() : null,
          );
    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext();
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกรหัสผ่านแล้ว')));
    } else {
      setState(() {
        _error = auth.error;
        _showNonce = auth.requiresPasswordNonce;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dark = context.watch<SettingsProvider>().isDarkMode;
    return PopScope(
      canPop: !auth.isLoading,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppModalBottomSheetHeader(
                    title: auth.hasPassword
                        ? 'เปลี่ยนรหัสผ่าน'
                        : 'ตั้งรหัสผ่าน',
                  ),
                  if (auth.hasPassword) ...[
                    TextFormField(
                      controller: _current,
                      enabled: !auth.isLoading,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'รหัสผ่านปัจจุบัน',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'กรุณากรอกรหัสผ่านปัจจุบัน'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _password,
                    enabled: !auth.isLoading,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่านใหม่',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !auth.isLoading,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'ยืนยันรหัสผ่านใหม่',
                    ),
                    validator: (v) =>
                        v != _password.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                  ),
                  if (_showNonce) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nonce,
                      enabled: !auth.isLoading,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'รหัสยืนยันทางอีเมล',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'กรุณากรอกรหัสยืนยัน'
                          : null,
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              await auth.resendPasswordNonce();
                              if (mounted) {
                                setState(
                                  () => _error =
                                      auth.error ?? 'ส่งรหัสยืนยันใหม่แล้ว',
                                );
                              }
                            },
                      child: const Text('ขอรหัสยืนยันใหม่'),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.expenseFor(dark)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _save,
                    child: Text(auth.isLoading ? 'กำลังบันทึก…' : 'บันทึก'),
                  ),
                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
