/// Non-web fallback (today just `flutter test`'s VM target): there is no page
/// URL to carry the flag, so sessions are always restored as before.
bool consumeFreshLoginRequest() => false;
