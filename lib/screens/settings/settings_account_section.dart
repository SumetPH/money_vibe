import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_widgets.dart';

/// รายการในหมวด "บัญชีผู้ใช้" เมื่อ login แล้ว: ชื่อผู้ใช้/อีเมล และออกจากระบบ
class SettingsAccountSection extends StatelessWidget {
  final String? userEmail;
  final String? username;
  final bool isDarkMode;
  final bool isBusy;
  final bool isUpdatingUsername;
  final VoidCallback onEditUsername;
  final VoidCallback onLogout;

  const SettingsAccountSection({
    super.key,
    required this.userEmail,
    this.username,
    required this.isDarkMode,
    required this.isBusy,
    required this.isUpdatingUsername,
    required this.onEditUsername,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);
    final destructiveColor = AppColors.expenseFor(isDarkMode);

    return Column(
      children: [
        ListTile(
          leading: SettingsIcon(icon: Icons.person, color: secondaryTextColor),
          title: Text(
            username ?? userEmail ?? 'ผู้ใช้',
            style: TextStyle(color: textColor, fontSize: 16),
          ),
          subtitle: Text(
            username != null ? userEmail ?? '' : 'อีเมลปัจจุบัน',
            style: TextStyle(color: secondaryTextColor, fontSize: 13),
          ),
          trailing: isUpdatingUsername
              ? SettingsBusyIndicator(color: secondaryTextColor)
              : Icon(Icons.edit_outlined, color: secondaryTextColor),
          enabled: !isBusy && !isUpdatingUsername,
          onTap: onEditUsername,
        ),
        Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
        ListTile(
          enabled: !isBusy,
          leading: SettingsIcon(icon: Icons.logout, color: destructiveColor),
          title: Text('ออกจากระบบ', style: TextStyle(color: destructiveColor)),
          onTap: onLogout,
        ),
      ],
    );
  }
}

/// แถว "ลบบัญชี" แยกไว้ล่างสุดของหน้า Settings
class SettingsDeleteAccountTile extends StatelessWidget {
  final bool isDarkMode;
  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onDeleteAccount;

  const SettingsDeleteAccountTile({
    super.key,
    required this.isDarkMode,
    required this.isBusy,
    required this.isDeleting,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final destructiveColor = AppColors.expenseFor(isDarkMode);

    return ListTile(
      enabled: !isBusy && !isDeleting,
      leading: SettingsIcon(
        icon: Icons.delete_forever_outlined,
        color: destructiveColor,
      ),
      title: Text('ลบบัญชี', style: TextStyle(color: destructiveColor)),
      subtitle: Text(
        'ลบบัญชีและข้อมูลทั้งหมดบนคลาวด์อย่างถาวร',
        style: TextStyle(
          color: AppColors.textSecondaryFor(isDarkMode),
          fontSize: 13,
        ),
      ),
      trailing: isDeleting
          ? SettingsBusyIndicator(color: destructiveColor)
          : null,
      onTap: onDeleteAccount,
    );
  }
}

class SettingsBusyIndicator extends StatelessWidget {
  final Color color;

  const SettingsBusyIndicator({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
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

/// เนื้อหา dialog เปลี่ยนชื่อผู้ใช้; ถือ TextEditingController เองเพื่อให้ dispose
/// หลัง dialog เล่น animation ปิดจบแล้ว
class SettingsUsernameEditContent extends StatefulWidget {
  static const maxLength = 50;

  final String initialUsername;
  final bool isDarkMode;
  final ValueChanged<String> onUsernameChanged;

  const SettingsUsernameEditContent({
    super.key,
    required this.initialUsername,
    required this.isDarkMode,
    required this.onUsernameChanged,
  });

  @override
  State<SettingsUsernameEditContent> createState() =>
      _SettingsUsernameEditContentState();
}

class _SettingsUsernameEditContentState
    extends State<SettingsUsernameEditContent> {
  late final _usernameController = TextEditingController(
    text: widget.initialUsername,
  );

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _usernameController,
      autofocus: true,
      maxLength: SettingsUsernameEditContent.maxLength,
      style: TextStyle(color: AppColors.textPrimaryFor(widget.isDarkMode)),
      decoration: const InputDecoration(hintText: 'ชื่อผู้ใช้'),
      onChanged: widget.onUsernameChanged,
    );
  }
}
