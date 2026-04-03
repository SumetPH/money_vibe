import 'package:web/web.dart' as web;

double? _cachedBottomInset;

double getWebSafeAreaBottomInset() {
  return _cachedBottomInset ??= _readSafeAreaInsetBottom();
}

bool isMobileWebDevice() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('android') ||
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod') ||
      userAgent.contains('mobile');
}

double _readSafeAreaInsetBottom() {
  final body = web.document.body;
  if (body == null) {
    return 0;
  }

  final envProbe = web.HTMLDivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.visibility = 'hidden'
    ..style.pointerEvents = 'none'
    ..style.paddingBottom = 'env(safe-area-inset-bottom)';

  final constantProbe = web.HTMLDivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.visibility = 'hidden'
    ..style.pointerEvents = 'none'
    ..style.paddingBottom = 'constant(safe-area-inset-bottom)';

  body
    ..append(envProbe)
    ..append(constantProbe);

  final envInset = _parsePixels(
    web.window.getComputedStyle(envProbe).paddingBottom,
  );
  final constantInset = _parsePixels(
    web.window.getComputedStyle(constantProbe).paddingBottom,
  );

  envProbe.remove();
  constantProbe.remove();

  return envInset > constantInset ? envInset : constantInset;
}

double _parsePixels(String value) {
  return double.tryParse(value.replaceAll('px', '').trim()) ?? 0;
}
