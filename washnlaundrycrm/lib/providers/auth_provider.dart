import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Sign-In state for the `/login` screen.
///
/// Deliberately UI-only: it gates which screen `main.dart` shows, matching
/// the real app's `/login` -> `/dashboard` swap once `onAuthStateChanged`
/// fires. It does **not** protect the Django API — that stays open, as
/// documented in CLAUDE.md ("no auth, no permissions"). Wiring a real,
/// server-verified session is a separate, larger change.
class AuthProvider extends ChangeNotifier {
  /// The Client ID from Google Cloud Console — Credentials > OAuth 2.0
  /// Client IDs > (Web application). Passed the same way `API_BASE_URL` is:
  /// `--dart-define=GOOGLE_CLIENT_ID=...`. Sign-in is disabled, with an
  /// explanatory screen instead of a broken button, until this is set.
  static const _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static bool get isConfigured => _clientId.isNotEmpty;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initializing = true;
  bool get initializing => _initializing;

  bool _isPersistedSignedIn = false;
  String? _persistedEmail;
  String? _persistedName;

  GoogleSignInAccount? _account;
  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null || _isPersistedSignedIn;
  String? get userEmail => _account?.email ?? _persistedEmail;
  String? get userName => _account?.displayName ?? _persistedName;

  String? _error;
  String? get error => _error;

  AuthProvider() {
    if (isConfigured) {
      _init();
    } else {
      _initializing = false;
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPersistedSignedIn = prefs.getBool('is_signed_in') ?? false;
      _persistedEmail = prefs.getString('user_email');
      _persistedName = prefs.getString('user_name');

      await _googleSignIn.initialize(clientId: _clientId);
      _googleSignIn.authenticationEvents.listen(_handleEvent, onError: (e) {
        _error = _messageFor(e);
        notifyListeners();
      });
      // Silently restores a still-live Google session — the equivalent of
      // the real app's `onAuthStateChanged` firing on a page reload, rather
      // than forcing every reload back through the sign-in button.
      await _googleSignIn.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      _error = _messageFor(e);
    } catch (_) {
      // Ignored: lightweight auth or prefs shouldn't crash initialization.
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  void _handleEvent(GoogleSignInAuthenticationEvent event) {
    _error = null;
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _account = event.user;
        _isPersistedSignedIn = true;
        _persistedEmail = event.user.email;
        _persistedName = event.user.displayName;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_signed_in', true);
          prefs.setString('user_email', event.user.email);
          if (event.user.displayName != null) {
            prefs.setString('user_name', event.user.displayName!);
          }
        });
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
        _isPersistedSignedIn = false;
        _persistedEmail = null;
        _persistedName = null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('is_signed_in');
          prefs.remove('user_email');
          prefs.remove('user_name');
        });
    }
    notifyListeners();
  }

  String _messageFor(Object e) {
    if (e is GoogleSignInException) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Sign-in was cancelled.';
        default:
          return e.description ?? 'Could not sign in with Google.';
      }
    }
    return 'Could not sign in with Google.';
  }

  /// Triggers a full interactive sign-in. Not supported on web — the GIS SDK
  /// only allows signing in through UI it renders itself
  /// ([GoogleSignIn.supportsAuthenticate] is false there), which is why the
  /// web build renders Google's own button instead of calling this from one
  /// of ours. See `utils/google_signin_button_web.dart`.
  Future<void> authenticate() async {
    try {
      await _googleSignIn.authenticate();
      // The resulting account arrives via [_handleEvent] — the platform's
      // authenticationEvents stream is the single source of truth so a
      // native sign-in and a restored one update state identically.
    } on GoogleSignInException catch (e) {
      _error = _messageFor(e);
      notifyListeners();
    }
  }

  Future<void> signInAsDemo() async {
    _isPersistedSignedIn = true;
    _persistedEmail = 'demo@laundrybill.com';
    _persistedName = 'Demo Owner';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_signed_in', true);
    await prefs.setString('user_email', 'demo@laundrybill.com');
    await prefs.setString('user_name', 'Demo Owner');
    _error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _isPersistedSignedIn = false;
    _persistedEmail = null;
    _persistedName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_signed_in');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    notifyListeners();
  }
}
