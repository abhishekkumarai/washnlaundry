/// Non-web fallback — selected by `csv_download.dart`'s conditional export
/// when compiling off web (today that's just `flutter test`'s VM target;
/// this app doesn't ship to Android/Windows yet — see CLAUDE.md). Returns
/// false so callers can show a "not available" message instead of silently
/// doing nothing.
bool downloadCsv(String filename, String csvContent) => false;
bool downloadString(String filename, String content, {String mimeType = 'text/plain;charset=utf-8;'}) => false;
bool downloadBytes(String filename, List<int> bytes, {String mimeType = 'application/octet-stream'}) => false;
