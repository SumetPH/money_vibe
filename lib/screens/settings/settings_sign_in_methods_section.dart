import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_inset_card.dart';
import 'settings_password_sheet.dart';
import 'settings_widgets.dart';

class SettingsSignInMethodsSection extends StatelessWidget {
  const SettingsSignInMethodsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const SizedBox.shrink();
    final dark = context.watch<SettingsProvider>().isDarkMode;
    final color = AppColors.textSecondaryFor(dark);
    final identity = auth.linkedGoogleIdentity;
    final busy = auth.isLoading || auth.isDeletingAccount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader('ช่องทางเข้าสู่ระบบ'),
        SettingsGroup(
          isDarkMode: dark,
          child: Column(
            children: [
              if (!auth.signInMethodsReady)
                ListTile(
                  title: const Text('โหลดช่องทางเข้าสู่ระบบไม่สำเร็จ'),
                  trailing: TextButton(
                    onPressed: busy ? null : auth.reloadSignInMethods,
                    child: const Text('ลองใหม่'),
                  ),
                )
              else
                ListTile(
                  leading: SettingsIcon(icon: Icons.password, color: color),
                  title: Text(
                    auth.hasPassword ? 'เปลี่ยนรหัสผ่าน' : 'ตั้งรหัสผ่าน',
                  ),
                  trailing: Icon(Icons.chevron_right, color: color),
                  enabled: !busy,
                  onTap: () {
                    auth.clearError();
                    showSettingsPasswordSheet(context);
                  },
                ),
              if (auth.isGoogleAvailable) ...[
                const AppCardDivider(),
                ListTile(
                  leading: SettingsIcon(icon: Icons.link, color: color),
                  title: const Text('Google'),
                  subtitle: Text(
                    identity == null
                        ? 'ยังไม่ได้เชื่อม'
                        : identity.identityData?['email'] as String? ?? '',
                  ),
                  trailing: identity == null
                      ? TextButton(
                          onPressed: busy ? null : () => _link(context, auth),
                          child: const Text('เชื่อม Google'),
                        )
                      : auth.canUnlinkGoogle
                      ? TextButton(
                          onPressed: busy ? null : () => _unlink(context, auth),
                          child: const Text('ยกเลิกการเชื่อม'),
                        )
                      : null,
                ),
              ],
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    auth.error!,
                    style: TextStyle(color: AppColors.expenseFor(dark)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _link(BuildContext context, AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.linkGoogle();
    if (success && !auth.isLoading) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ดำเนินการเชื่อม Google แล้ว')),
      );
    }
  }

  Future<void> _unlink(BuildContext context, AuthProvider auth) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ยกเลิกการเชื่อม Google?',
      message: 'คุณจะเข้าสู่ระบบด้วย Google นี้ไม่ได้อีก กรุณาใช้รหัสผ่านแทน',
      confirmLabel: 'ยกเลิกการเชื่อม',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await auth.unlinkGoogle();
  }
}
