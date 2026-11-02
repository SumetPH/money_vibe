import 'web_redirect_stub.dart'
    if (dart.library.html) 'web_redirect_web.dart'
    as impl;

/// พาแท็บปัจจุบันไปยัง [url] โดยตรง (ไม่ใช้ window.open ที่ Safari บล็อกเป็น popup)
void redirectWebTo(String url) => impl.redirectWebTo(url);
