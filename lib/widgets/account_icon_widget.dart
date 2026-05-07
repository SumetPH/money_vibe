import 'package:flutter/material.dart';
import '../models/account.dart';
import '../theme/app_colors.dart';

/// A widget that displays an account icon.
/// Shows a network image if [account.iconUrl] is set (user-uploaded),
/// otherwise falls back to the Material [account.icon].
class AccountIconWidget extends StatelessWidget {
  final Account account;
  final double size;
  final bool isDarkMode;

  const AccountIconWidget({
    super.key,
    required this.account,
    this.size = 20,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (account.iconUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: account.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            account.iconUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildIconFallback();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildLoadingIndicator();
            },
          ),
        ),
      );
    }
    return _buildIconFallback();
  }

  Widget _buildIconFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: account.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          account.icon,
          color: account.color,
          size: size * 0.6,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurface : Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
