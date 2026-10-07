import 'package:web/web.dart' as web;

/// True when the page was opened with `?fresh=1`. The flag is removed from the
/// address bar as it is read, so reloading after signing in does not sign the
/// user out again. Selected by `fresh_login.dart` only when compiling for web.
bool consumeFreshLoginRequest() {
  final loc = web.window.location;
  final search = loc.search.startsWith('?') ? loc.search.substring(1) : loc.search;
  final params = Uri.splitQueryString(search);
  if (params['fresh'] != '1') return false;

  params.remove('fresh');
  final query =
      params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
  web.window.history.replaceState(null, '', '${loc.pathname}$query${loc.hash}');
  return true;
}
