/// Non-web fallback — selected by `csv_download.dart`'s conditional export
/// when compiling off web (today that's just `flutter test`'s VM target;
/// this app doesn't ship to Android/Windows yet — see CLAUDE.md). Returns
/// false so callers can show a "not available" message instead of silently
/// doing nothing.
bool downloadCsv(String filename, String csvContent) => false;
