import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_widgets.dart';

/// รายการในหมวด "บัญชีผู้ใช้" เมื่อ login แล้ว: อีเมล, ออกจากระบบ และลบบัญชี
class SettingsAccountSection extends StatelessWidget {
  final String? userEmail;
  final bool isDarkMode;
  final bool isBusy;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const SettingsAccountSection({
    super.key,
    required this.userEmail,
    required this.isDarkMode,
    required this.isBusy,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);
    final destructiveColor = AppColors.expenseFor(isDarkMode);
    final divider = Divider(
      height: 1,
      color: AppColors.listDividerFor(isDarkMode),
    );

    return Column(
      children: [
        ListTile(
          leading: SettingsIcon(icon: Icons.person, color: secondaryTextColor),
          title: Text(
            userEmail ?? 'ผู้ใช้',
            style: TextStyle(color: textColor, fontSize: 16),
          ),
          subtitle: Text(
            'อีเมลปัจจุบัน',
            style: TextStyle(color: secondaryTextColor, fontSize: 13),
          ),
        ),
        divider,
        ListTile(
          enabled: !isBusy,
          leading: SettingsIcon(icon: Icons.logout, color: destructiveColor),
          title: Text('ออกจากระบบ', style: TextStyle(color: destructiveColor)),
          onTap: onLogout,
        ),
        divider,
        ListTile(
          enabled: !isBusy,
          leading: SettingsIcon(
            icon: Icons.delete_forever_outlined,
            color: destructiveColor,
          ),
          title: Text('ลบบัญชี', style: TextStyle(color: destructiveColor)),
          subtitle: Text(
            'ลบบัญชีและข้อมูลทั้งหมดบนคลาวด์อย่างถาวร',
            style: TextStyle(color: secondaryTextColor, fontSize: 13),
          ),
          trailing: isBusy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: destructiveColor,
                  ),
                )
              : null,
          onTap: onDeleteAccount,
        ),
      ],
    );
  }
}

/// เนื้อหา dialog ยืนยันการลบบัญชี; ถือ TextEditingController เองเพื่อให้ dispose
/// หลัง dialog เล่น animation ปิดจบแล้ว (ไม่ใช่ทันทีที่ dialog คืนค่า)
class SettingsDeleteAccountConfirmContent extends StatefulWidget {
  final String email;
  final bool isDarkMode;
  final ValueChanged<String> onEmailChanged;

  const SettingsDeleteAccountConfirmContent({
    super.key,
    required this.email,
    required this.isDarkMode,
    required this.onEmailChanged,
  });

  @override
  State<SettingsDeleteAccountConfirmContent> createState() =>
      _SettingsDeleteAccountConfirmContentState();
}

class _SettingsDeleteAccountConfirmContentState
    extends State<SettingsDeleteAccountConfirmContent> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(widget.isDarkMode);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'บัญชี ธุรกรรม งบประมาณ พอร์ต และไฟล์ทั้งหมดบนคลาวด์จะถูกลบ '
            'และกู้คืนไม่ได้ แนะนำให้ส่งออกข้อมูลก่อน\n\n'
            'พิมพ์อีเมล ${widget.email} เพื่อยืนยัน',
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: TextStyle(color: textColor),
            decoration: const InputDecoration(hintText: 'อีเมล'),
            onChanged: widget.onEmailChanged,
          ),
        ],
      ),
    );
  }
}
