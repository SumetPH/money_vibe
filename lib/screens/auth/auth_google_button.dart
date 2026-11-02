import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import 'auth_google_logo.dart';

class AuthGoogleButton extends StatelessWidget {
  final bool isLoading;
  final bool isDarkMode;
  final VoidCallback onPressed;
  const AuthGoogleButton({
    super.key,
    required this.isLoading,
    required this.isDarkMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);
    final divider = Expanded(
      child: Divider(color: AppColors.borderFor(isDarkMode)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              divider,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'หรือ',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ),
              divider,
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.raisedFillFor(isDarkMode),
              foregroundColor: AppColors.textPrimaryFor(isDarkMode),
              side: BorderSide(color: AppColors.borderFor(isDarkMode)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const AuthGoogleLogo(),
            label: const Text('Google'),
          ),
        ),
      ],
    );
  }
}
