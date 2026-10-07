import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/fresh_login.dart';
import '../utils/role_views.dart';

/// Google Sign-In state for the `/login` screen, plus the server-verified role.
///
/// After Google sign-in the ID token is sent to the backend as a Bearer token
/// (`ApiService.tokenProvider`) and `/api/me/` says whether this account is
/// `owner` (everything), `staff` (orders, customers, scanning), a `customer` (their own orders only) or `unlinked`.
/// The router picks the UI from [role]; the API enforces it when the backend
/// has API_AUTH_ENFORCED on. Demo Mode has no token, so it is always `owner`
/// and only works against a backend that is not enforcing auth.
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

  /// 'owner' | 'staff' | 'customer' | 'unlinked'; null until `/api/me/` answers.
  String? _role;
  String? get role => _role;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? get me => _me;
  bool _roleLoading = false;
  bool get roleLoading => _roleLoading;
  String? _roleError;
  String? get roleError => _roleError;
  bool _isDemo = false;

  /// Session token from email/password sign-in (`Bearer app.…`), if that's how
  /// the user signed in. Google sign-in uses the Google ID token instead.
  String? _appToken;

  AuthProvider() {
    ApiService.tokenProvider = _idToken;
    ApiService.onUnauthorized = _refreshToken;
    _init();
  }

  Future<String?> _idToken() async =>
      _appToken ?? _account?.authentication.idToken;

  /// Google ID tokens last about an hour; ask GIS for a fresh one after a 401.
  Future<bool> _refreshToken() async {
    // A password session can't be silently renewed; it just ends.
    if (!isConfigured || _isDemo || _appToken != null) return false;
    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      return false;
    }
    return _account != null;
  }

  @visibleForTesting
  void setSessionForTest({required bool signedIn, String? role}) {
    _initializing = false;
    _isPersistedSignedIn = signedIn;
    _role = role;
    notifyListeners();
  }

  /// Fetches `/api/me/` and stores the role. Safe to call again to retry.
  Future<void> refreshRole() async {
    if (_isDemo) {
      _role = 'owner';
      notifyListeners();
      return;
    }
    if (_account == null && _appToken == null) return;
    _roleLoading = true;
    _roleError = null;
    notifyListeners();
    try {
      _me = await ApiService.fetchMe();
      _role = RoleViews.effectiveRole(_me!['role'] as String?);
    } on ApiException catch (e) {
      _role = null;
      _roleError = e.message;
      if (e.statusCode == 401 && _appToken != null) {
        // Expired or revoked (e.g. password changed elsewhere): back to /login.
        await signOut();
        _error = 'Your session expired. Please sign in again.';
      }
    } finally {
      _roleLoading = false;
      notifyListeners();
    }
  }

  Future<void> _init() async {
    try {
      // Restoring a persisted session (Demo Mode or Google) needs this read
      // regardless of `isConfigured` — a Demo Mode sign-in must survive a
      // page reload even when there's no Google client ID to restore via.
      final prefs = await SharedPreferences.getInstance();
      // Opened from the marketing site's "Log in" link (`/?fresh=1`): show the
      // login screen rather than quietly signing back in to whatever session
      // this browser still has stored.
      final fresh = consumeFreshLoginRequest();
      if (fresh) {
        for (final key in const [
          'is_signed_in',
          'is_demo',
          'app_token',
          'user_email',
          'user_name',
        ]) {
          await prefs.remove(key);
        }
      }
      _isPersistedSignedIn = prefs.getBool('is_signed_in') ?? false;
      _persistedEmail = prefs.getString('user_email');
      _persistedName = prefs.getString('user_name');
      _isDemo = prefs.getBool('is_demo') ?? false;
      if (_isDemo) _role = 'owner';
      _appToken = prefs.getString('app_token');

      if (isConfigured) {
        await _googleSignIn.initialize(clientId: _clientId);
        _googleSignIn.authenticationEvents.listen(_handleEvent, onError: (e) {
          _error = _messageFor(e);
          notifyListeners();
        });
        if (fresh) {
          // Also drop Google's own session, or the silent restore below would
          // sign straight back in.
          await _googleSignIn.signOut();
        } else {
          // Silently restores a still-live Google session — the equivalent of
          // the real app's `onAuthStateChanged` firing on a page reload, rather
          // than forcing every reload back through the sign-in button.
          await _googleSignIn.attemptLightweightAuthentication();
        }
      }
      // A persisted Google session with no live account has no ID token to
      // send, so the API would reject everything: make the user sign in again.
      if (_appToken != null && _isPersistedSignedIn) {
        await refreshRole();
      } else if (!_isDemo && _isPersistedSignedIn && _account == null) {
        _isPersistedSignedIn = false;
        _persistedEmail = null;
        _persistedName = null;
        await prefs.remove('is_signed_in');
      }
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
        _appToken = null;
        _isDemo = false;
        _isPersistedSignedIn = true;
        _persistedEmail = event.user.email;
        _persistedName = event.user.displayName;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_signed_in', true);
          prefs.setString('user_email', event.user.email);
          prefs.remove('is_demo');
          prefs.remove('app_token');
          if (event.user.displayName != null) {
            prefs.setString('user_name', event.user.displayName!);
          }
        });
        refreshRole();
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
        _isPersistedSignedIn = false;
        _persistedEmail = null;
        _persistedName = null;
        _clearRole();
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('is_demo');
          prefs.remove('app_token');
          prefs.remove('is_signed_in');
          prefs.remove('user_email');
          prefs.remove('user_name');
        });
    }
    notifyListeners();
  }

  void _clearRole() {
    _appToken = null;
    _role = null;
    _me = null;
    _roleError = null;
    _roleLoading = false;
    _isDemo = false;
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

  // ── Email + password ───────────────────────────────────────────────────────
  // Each returns an error message to show, or null on success.

  Future<String?> _guard(Future<void> Function() call) async {
    try {
      await call();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> _startPasswordSession(Map<String, dynamic> res) async {
    _appToken = res['token'] as String;
    _isDemo = false;
    _isPersistedSignedIn = true;
    _persistedEmail = res['email'] as String?;
    _persistedName = null;
    _error = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_signed_in', true);
    await prefs.remove('is_demo');
    await prefs.setString('app_token', _appToken!);
    if (_persistedEmail != null) {
      await prefs.setString('user_email', _persistedEmail!);
    }
    notifyListeners();
    await refreshRole();
  }

  Future<String?> signInWithPassword(String email, String password) =>
      _guard(() async => _startPasswordSession(
          await ApiService.logIn(email.trim(), password)));

  /// On success the account exists but must confirm its email before signing in.
  Future<String?> signUpWithPassword(
          String email, String password, String name, String phone) =>
      _guard(() =>
          ApiService.signUp(email.trim(), password, name.trim(), phone.trim()));

  /// Saves the signed-in customer's profile; null on success, else the error.
  Future<String?> saveCustomerProfile(Map<String, String> fields) async {
    try {
      final updated = await ApiService.updateMyProfile(fields);
      _me = {
        ...?_me,
        'customer': {...?(_me?['customer'] as Map?)?.cast<String, dynamic>(), ...updated},
      };
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> confirmEmail(String token) => _guard(() async =>
      _startPasswordSession(await ApiService.verifyEmail(token)));

  Future<String?> requestPasswordReset(String email) =>
      _guard(() => ApiService.forgotPassword(email.trim()));

  Future<String?> resetPassword(String token, String password) =>
      _guard(() async => _startPasswordSession(
          await ApiService.resetPassword(token, password)));

  Future<void> signInAsDemo() async {
    _isDemo = true;
    _role = 'owner';
    _isPersistedSignedIn = true;
    _persistedEmail = 'demo@washnlaundry.com';
    _persistedName = 'Demo Owner';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_signed_in', true);
    await prefs.setBool('is_demo', true);
    await prefs.setString('user_email', 'demo@washnlaundry.com');
    await prefs.setString('user_name', 'Demo Owner');
    _error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (isConfigured) {
      await _googleSignIn.signOut();
    }
    _account = null;
    _isPersistedSignedIn = false;
    _persistedEmail = null;
    _persistedName = null;
    _clearRole();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_demo');
    await prefs.remove('app_token');
    await prefs.remove('is_signed_in');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    notifyListeners();
  }
}
