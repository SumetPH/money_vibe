import 'package:flutter/material.dart';

class AppBarActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isLoading;
  final bool disableWhenLoading;
  final Widget? loadingIcon;

  const AppBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isLoading = false,
    this.disableWhenLoading = true,
    this.loadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: isLoading && disableWhenLoading ? null : onPressed,
      icon: isLoading
          ? loadingIcon ??
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
          : icon,
    );
  }
}
