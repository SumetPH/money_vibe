import 'package:flutter/material.dart';

import 'auth_google_logo.dart';

class AuthGoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const AuthGoogleButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('หรือ'),
            ),
            Expanded(child: Divider()),
          ],
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: const AuthGoogleLogo(),
          label: const Text('Google'),
        ),
      ),
    ],
  );
}
