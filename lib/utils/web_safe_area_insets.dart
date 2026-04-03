import 'web_safe_area_insets_stub.dart'
    if (dart.library.html) 'web_safe_area_insets_web.dart'
    as impl;

double getWebSafeAreaBottomInset() => impl.getWebSafeAreaBottomInset();

bool isMobileWebDevice() => impl.isMobileWebDevice();
