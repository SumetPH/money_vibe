import 'package:flutter/material.dart';

import '../theme/app_radii.dart';

/// รูปโปรไฟล์ผู้ใช้ทรงสี่เหลี่ยมมุมมน ถ้าไม่มี URL, กำลังโหลด หรือโหลดรูปไม่สำเร็จ จะแสดง [fallback] แทน
class AppUserAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final Widget fallback;

  const AppUserAvatar({
    super.key,
    required this.url,
    required this.size,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // รูปจาก Google อาจไม่ส่ง CORS header จึงให้ fallback เป็น <img> ของ browser
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
