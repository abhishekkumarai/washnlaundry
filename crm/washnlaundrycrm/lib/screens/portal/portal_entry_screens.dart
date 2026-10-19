import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/geolocation.dart';
import '../../utils/google_signin_button.dart';
import '../../widgets/brand_logo.dart';
import 'portal_shell.dart';

const _heading =
    TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.ink);
const _lede = TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.muted);
const _codeHeading =
    TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.ink);
const _label = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF475569));

/// Customer sign-in, laid out like the CRM login: Google, then Sign In / Create
/// Account tabs over email + password (api/password_auth.py; creating an account
/// emails a confirmation link, "Forgot password?" a reset link). The emailed
/// one-time code (no password) stays as the secondary way in, for customers who
/// already sign in that way. Sign-in comes first; the laundry list
/// ([FindShopScreen]) follows it.
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  /// Seconds before "Send again" is offered, so a slow inbox isn't hammered.
  static const resendAfter = 30;

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

enum _Mode { signIn, signUp, code }

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _obscure = true;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  int _resendIn = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() call, {VoidCallback? onOk}) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final err = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) onOk?.call();
    });
  }

  void _setMode(_Mode mode) => setState(() {
        _ticker?.cancel();
        _mode = mode;
        _codeSent = false;
        _code.clear();
        _error = null;
        _notice = null;
      });

  void _submit(AuthProvider auth) {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    if (_mode == _Mode.signIn) {
      _run(() => auth.signInWithPassword(email, _password.text));
      return;
    }
    // A 10-digit Indian mobile starting 6-9, the backend's `clean_phone` rule.
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim())) {
      setState(() => _error = 'Enter a valid 10-digit phone number.');
      return;
    }
    _run(() => auth.signUpWithPassword(email, _password.text, '', _phone.text), onOk: () {
      _notice = 'Check your inbox: we sent a link to confirm $email. '
          'Open it to finish creating your account.';
      _password.clear();
    });
  }

  Future<void> _forgotPassword(AuthProvider auth) async {
    final ctrl = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Send reset link')),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    _run(() => auth.requestPasswordReset(email),
        onOk: () => _notice = 'If $email has an account, we sent a link to reset the password.');
  }

  void _startResendTimer() {
    _ticker?.cancel();
    _resendIn = PortalLoginScreen.resendAfter;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _send(AuthProvider auth, {bool again = false}) {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter the email you want your bookings under.');
      return;
    }
    _run(() => auth.requestEmailCode(_email.text), onOk: () {
      _codeSent = true;
      _code.clear();
      if (again) _notice = 'A new code is on its way.';
      _startResendTimer();
    });
  }

  void _verify(AuthProvider auth) {
    if (_code.text.length != 6) {
      setState(() => _error = 'The code has 6 digits.');
      return;
    }
    _run(() => auth.signInWithEmailCode(_email.text, _code.text));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final error = _error ?? auth.error;
    return PortalPage(children: [
      const _Brand(),
      const SizedBox(height: 6),
      const Text('Sign in to book pickups and track your orders',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted)),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: auth.initializing
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            : AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null)
                      _banner(error, const Color(0xFFFEF2F2), AppColors.danger),
                    if (_notice != null)
                      _banner(_notice!, const Color(0xFFECFDF5), const Color(0xFF047857)),
                    ...(_mode == _Mode.code
                        ? (_codeSent ? _codeStep(auth) : _emailCodeStep(auth))
                        : _passwordForm(auth)),
                  ],
                ),
              ),
      ),
      const SizedBox(height: 16),
      const Text(
        'By signing in, you agree to our Terms of Service and Privacy Policy.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ]);
  }

  List<Widget> _passwordForm(AuthProvider auth) {
    final signUp = _mode == _Mode.signUp;
    return [
      if (AuthProvider.isConfigured) ...[
        Center(child: googleSignInButton(onPressed: auth.authenticate)),
        const SizedBox(height: 16),
        _divider('OR'),
        const SizedBox(height: 16),
      ],
      _tabs(),
      const SizedBox(height: 16),
      _fieldLabel('Email'),
      const SizedBox(height: 6),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: _field(hint: 'you@example.com', icon: Icons.mail_outline_rounded),
      ),
      if (signUp) ...[
        const SizedBox(height: 14),
        _fieldLabel('Phone number'),
        const SizedBox(height: 6),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: _field(hint: '9876543210', icon: Icons.phone_outlined),
        ),
      ],
      const SizedBox(height: 14),
      _fieldLabel('Password'),
      const SizedBox(height: 6),
      TextField(
        controller: _password,
        obscureText: _obscure,
        autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
        onSubmitted: (_) => _submit(auth),
        decoration: _field(hint: 'Enter your password', icon: Icons.lock_outline_rounded)
            .copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18, color: AppColors.muted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      if (!signUp)
        Align(
          alignment: Alignment.centerLeft,
          child: _link('Forgot password?', () => _forgotPassword(auth)),
        ),
      const SizedBox(height: 12),
      _primary(_busy ? 'Please wait…' : (signUp ? 'Create Account' : 'Sign In'),
          () => _submit(auth)),
      const SizedBox(height: 10),
      Center(child: _link('Email me a sign-in code instead', () => _setMode(_Mode.code))),
    ];
  }

  List<Widget> _emailCodeStep(AuthProvider auth) => [
        const Text('Sign in with a code', style: _codeHeading),
        const SizedBox(height: 6),
        const Text('We email you a 6-digit code. It works for 10 minutes.', style: _lede),
        const SizedBox(height: 18),
        _fieldLabel('Email'),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          decoration: _field(hint: 'you@example.com', icon: Icons.mail_outline_rounded),
          onSubmitted: (_) => _send(auth),
        ),
        const SizedBox(height: 16),
        _primary(_busy ? 'Sending…' : 'Email me a code', () => _send(auth)),
        const SizedBox(height: 10),
        Center(child: _link('Use a password instead', () => _setMode(_Mode.signIn))),
      ];

  List<Widget> _codeStep(AuthProvider auth) {
    // Wide digit spacing reads like a code, but must still fit a small phone.
    final spacing = MediaQuery.sizeOf(context).width < 380 ? 6.0 : 14.0;
    return [
      const Text('Check your email', style: _codeHeading),
      const SizedBox(height: 6),
      _sentTo(),
      const SizedBox(height: 18),
      _fieldLabel('Code'),
      const SizedBox(height: 6),
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: spacing,
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()]),
        decoration: _field(hint: '000000').copyWith(
            counterText: '',
            hintStyle:
                TextStyle(fontSize: 26, letterSpacing: spacing, color: const Color(0xFFD5D1C8))),
        // A full code signs in straight away, as autofilled codes do.
        onChanged: (v) {
          if (v.length == 6 && !_busy) _verify(auth);
        },
        onSubmitted: (_) => _verify(auth),
      ),
      const SizedBox(height: 16),
      _primary(_busy ? 'Signing in…' : 'Sign in', () => _verify(auth)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No email?', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          TextButton(
            onPressed: _busy || _resendIn > 0 ? null : () => _send(auth, again: true),
            child: Text(_resendIn > 0 ? 'Send again in ${_resendIn}s' : 'Send again'),
          ),
        ],
      ),
      Center(child: _link('Use a password instead', () => _setMode(_Mode.signIn))),
    ];
  }

  Widget _sentTo() => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(TextSpan(style: _lede, children: [
            const TextSpan(text: 'We sent a 6-digit code to '),
            TextSpan(
                text: _email.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
            const TextSpan(text: '.'),
          ])),
          TextButton(
            onPressed: _busy ? null : () => _setMode(_Mode.code),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Change'),
          ),
        ],
      );

  /// Sign In / Create Account, the CRM login's segmented switch.
  Widget _tabs() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFEA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(child: _tab(_Mode.signIn, 'Sign In')),
          Expanded(child: _tab(_Mode.signUp, 'Create Account')),
        ]),
      );

  Widget _tab(_Mode mode, String label) {
    final selected = _mode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => _setMode(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(String text) => Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ]);

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)));

  Widget _link(String text, VoidCallback onTap) => InkWell(
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _primary(String text, VoidCallback onPressed) => FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        child: Text(text),
      );

  Widget _banner(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: fg)),
      );

  InputDecoration _field({required String hint, IconData? icon}) {
    OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: edge(AppColors.border),
      enabledBorder: edge(AppColors.border),
      focusedBorder: edge(AppColors.primary),
    );
  }
}

/// Logo and wordmark, as on the CRM login.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Column(children: [
        BrandLogo(size: 64),
        SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'WashN', style: TextStyle(color: AppColors.ink)),
            TextSpan(text: 'Laundry', style: TextStyle(color: AppColors.accent)),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ]);
}

/// Home after sign-in, until a shop is chosen: the customer's own laundries
/// first, then every laundry taking online bookings, searchable by name, area
/// or pincode. Picking one opens booking (or joining) for it.
class FindShopScreen extends StatefulWidget {
  const FindShopScreen({super.key});

  @override
  State<FindShopScreen> createState() => _FindShopScreenState();
}

class _FindShopScreenState extends State<FindShopScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _shops;
  bool _busy = false;
  String? _opening;
  String? _error;
  Timer? _debounce;

  /// The customer's position once they agree to share it (remembered, so the
  /// list opens sorted by distance next time).
  (double, double)? _here;
  bool _locating = false;
  bool _locationFailed = false;

  static const _locationPref = 'portal_use_location';

  /// Laundries within this many km are "Nearby"; the rest follow, still by distance.
  static const _nearbyKm = 10.0;

  @override
  void initState() {
    super.initState();
    _search();
    SharedPreferences.getInstance().then((p) {
      if (mounted && p.getBool(_locationPref) == true) _locate(quiet: true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shops = await ApiService.searchShops(_q.text.trim(), near: _here);
      if (mounted) setState(() => _shops = shops);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// [quiet]: the remembered retry on open; if it fails, just offer the button.
  Future<void> _locate({bool quiet = false}) async {
    setState(() {
      _locating = true;
      _locationFailed = false;
    });
    final here = await currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _here = here;
      _locationFailed = here == null && !quiet;
    });
    try {
      if (!quiet || here != null) {
        (await SharedPreferences.getInstance()).setBool(_locationPref, here != null);
      }
    } catch (_) {}
    if (here != null) await _search();
  }

  void _onType(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _pick(String slug) async {
    setState(() {
      _opening = slug;
      _error = null;
    });
    final err = await context.read<PortalProvider>().selectShop(slug);
    if (!mounted) return;
    setState(() => _opening = null);
    if (err != null) {
      setState(() => _error = err);
    } else {
      context.go('/book');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final current = context.watch<PortalProvider>().shopSlug;
    final all = _shops ?? const <Map<String, dynamic>>[];
    final searching = _q.text.trim().isNotEmpty;
    final located = _here != null;
    final nearby = [
      for (final s in all)
        if ((s['distance_km'] as num?) != null && (s['distance_km'] as num) <= _nearbyKm) s
    ];
    final nearbySlugs = {for (final s in nearby) s['slug']};
    final rest = [
      for (final s in all)
        if (!nearbySlugs.contains(s['slug'])) s
    ];
    final first = (auth.userName ?? '').trim().split(' ').first;

    _ShopRow row(Map<String, dynamic> s) => _ShopRow(
          name: '${s['name']}',
          place: _place(s),
          distance: (s['distance_km'] as num?)?.toDouble(),
          badge: s['slug'] == current ? 'Current' : null,
          busy: _opening == s['slug'],
          onTap: () => _pick('${s['slug']}'),
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PortalNavBar(
        choosingShop: true,
        leading: current == null
            ? null
            : IconButton(
                tooltip: 'Back to booking',
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () => context.go('/book'),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(first.isEmpty ? 'Choose your laundry' : 'Hi $first, choose your laundry',
                        style: _heading),
                    const SizedBox(height: 6),
                    const Text('Pickup and delivery from laundries that take online bookings.',
                        style: _lede),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _q,
                      textInputAction: TextInputAction.search,
                      onChanged: _onType,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Search by name, area or pincode',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.muted),
                        suffixIcon: searching
                            ? IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _q.clear();
                                  _search();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    portalError(_error),
                    if (!searching) ...[
                      const SizedBox(height: 28),
                      Row(children: [
                        const Expanded(child: Text('NEARBY', style: _label)),
                        if (located)
                          TextButton.icon(
                            onPressed: _locating ? null : _locate,
                            icon: const Icon(Icons.my_location_rounded, size: 16),
                            label: const Text('Refresh'),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      if (!located)
                        _LocationPrompt(
                          busy: _locating,
                          failed: _locationFailed,
                          onUse: _locate,
                        )
                      else if (nearby.isEmpty && !_busy)
                        const PortalPanel(
                          child: Text(
                              'No laundry within 10 km takes online bookings yet. The ones below '
                              'are the closest; or search your pincode.',
                              style: TextStyle(color: AppColors.muted, height: 1.45)),
                        )
                      else
                        _ShopList(rows: [for (final s in nearby) row(s)]),
                    ],
                    const SizedBox(height: 28),
                    Text(
                        searching
                            ? 'RESULTS'
                            : located
                                ? 'MORE LAUNDRIES'
                                : 'ALL LAUNDRIES',
                        style: _label),
                    const SizedBox(height: 10),
                    if (_busy && _shops == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    else if ((searching ? all : rest).isEmpty)
                      PortalPanel(
                        child: Text(
                            searching
                                ? 'No laundry matches "${_q.text.trim()}". Try a nearby pincode, '
                                    'or ask your laundry for its booking link.'
                                : 'No other laundries take online bookings yet.',
                            style: const TextStyle(color: AppColors.muted, height: 1.45)),
                      )
                    else
                      _ShopList(rows: [for (final s in (searching ? all : rest)) row(s)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _place(Map<String, dynamic> s) => [s['address'], s['city'], s['pin_code']]
      .where((v) => v != null && '$v'.trim().isNotEmpty)
      .join(' · ');
}

/// Before the customer shares their location: why it helps, and the button.
class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.busy, required this.failed, required this.onUse});

  final bool busy;
  final bool failed;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final message = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(failed ? Icons.location_off_outlined : Icons.near_me_outlined,
          size: 20, color: failed ? AppColors.danger : AppColors.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
            failed
                ? 'Location is off. Allow it for this site, or search your pincode above.'
                : 'Share your location to see the laundries closest to you.',
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4)),
      ),
    ]);
    final button = OutlinedButton.icon(
      onPressed: busy ? null : onUse,
      icon: const Icon(Icons.my_location_rounded, size: 16),
      label: Text(busy ? 'Locating…' : 'Use my location'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return PortalPanel(
      child: MediaQuery.sizeOf(context).width < 480
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              message,
              const SizedBox(height: 12),
              button,
            ])
          : Row(children: [Expanded(child: message), const SizedBox(width: 12), button]),
    );
  }
}

/// Rows in one bordered block, split by hairlines (a list, not a stack of cards).
class _ShopList extends StatelessWidget {
  const _ShopList({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderSubtle),
            rows[i],
          ],
        ]),
      );
}

class _ShopRow extends StatelessWidget {
  const _ShopRow(
      {required this.name,
      required this.place,
      required this.onTap,
      this.badge,
      this.distance,
      this.busy = false});

  final String name;
  final String place;

  /// km from the customer, when they shared their location.
  final double? distance;
  final String? badge;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mutedFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                ],
              ]),
              if (place.isNotEmpty || distance != null) ...[
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    if (distance != null)
                      TextSpan(
                          text:
                              '${distance! < 1 ? distance!.toStringAsFixed(1) : distance!.round()} km'
                              '${place.isEmpty ? '' : '  ·  '}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: AppColors.primary)),
                    TextSpan(text: place),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}

/// `/s/<slug>`: a shop's own booking link (shared on WhatsApp, the QR on receipts).
/// It remembers the shop and moves on: to sign-in when signed out (the shop is
/// kept through it), else straight to booking or joining.
class ShopLinkScreen extends StatefulWidget {
  const ShopLinkScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ShopLinkScreen> createState() => _ShopLinkScreenState();
}

class _ShopLinkScreenState extends State<ShopLinkScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<PortalProvider>().selectShop(widget.slug).then((err) {
      if (!mounted) return;
      if (err == null) {
        context.go('/book');
      } else {
        setState(() => _error = err);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) {
      return const Scaffold(
          backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }
    return PortalPage(children: [
      const Text('This link is not taking bookings', style: _heading),
      const SizedBox(height: 8),
      Text(_error!, style: _lede),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => context.go('/find'), child: const Text('See other laundries')),
    ]);
  }
}

/// A signed-in account that is not yet this shop's customer: join with name +
/// phone. A phone the shop already has needs the owner's approval first.
class JoinShopScreen extends StatefulWidget {
  const JoinShopScreen({super.key});

  @override
  State<JoinShopScreen> createState() => _JoinShopScreenState();
}

class _JoinShopScreenState extends State<JoinShopScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _pending = false;

  /// First try joining with the details given to another laundry; the form
  /// only shows when there are none (a first-ever join).
  bool _autoJoining = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _pending = auth.me?['pending_link'] == true;
    _name.text = auth.userName ?? '';
    if (_pending || auth.serverRole == 'owner' || auth.serverRole == 'staff') {
      _autoJoining = false;
    } else {
      _autoJoin();
    }
  }

  Future<void> _autoJoin() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await ApiService.joinShop();
      if (res['pending'] == true) {
        _pending = true;
      } else {
        await auth.refreshRole(); // now `customer`: the router moves on to /book
      }
    } on ApiException catch (e) {
      // 400: nothing to reuse, so ask. Anything else is a real error to show.
      if (e.statusCode != 400) _error = e.message;
    } catch (_) {
      // Offline or similar: fall back to the form rather than spin forever.
    }
    if (mounted) setState(() => _autoJoining = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ApiService.joinShop(_name.text.trim(), _phone.text.trim());
      if (res['pending'] == true) {
        _pending = true;
      } else {
        await auth.refreshRole(); // now `customer`: the router moves on to /book
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final portal = context.watch<PortalProvider>();
    final role = auth.serverRole;
    final signOut = TextButton(onPressed: auth.signOut, child: const Text('Sign out'));
    final change = TextButton(
        onPressed: () => context.go('/find'), child: const Text('Choose another laundry'));

    if (role == 'owner' || role == 'staff') {
      return PortalPage(children: [
        Text('You work at ${portal.shopName}', style: _heading),
        const SizedBox(height: 8),
        const Text('Manage orders in the shop app. This site is for customers.', style: _lede),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => launchUrl(Uri.parse('https://app.washnlaundry.com/')),
          child: const Text('Open app.washnlaundry.com'),
        ),
        change,
        signOut,
      ]);
    }
    if (_autoJoining) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Joining ${portal.shopName}…', style: _lede),
          ]),
        ),
      );
    }
    if (_pending) {
      return PortalPage(children: [
        const Text('Waiting for the shop', style: _heading),
        const SizedBox(height: 8),
        Text(
            '${portal.shopName} already has your number. We have asked them to confirm '
            'it is you; your past orders appear here once they approve.',
            style: _lede),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: auth.refreshRole, child: const Text('Check again')),
        change,
        signOut,
      ]);
    }
    OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    InputDecoration field(String hint, IconData icon, {String? prefix}) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
          prefixText: prefix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: AppColors.card,
          border: edge(AppColors.border),
          enabledBorder: edge(AppColors.border),
          focusedBorder: edge(AppColors.primary, 1.5),
        );
    return PortalPage(children: [
      const _Brand(),
      const SizedBox(height: 28),
      PortalPanel(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('NEW CUSTOMER', style: _label),
          const SizedBox(height: 6),
          Text('Join ${portal.shopName}', style: _heading.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(style: _lede, children: [
              const TextSpan(text: 'Signed in as '),
              TextSpan(
                  text: auth.userEmail ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              const TextSpan(text: '. The shop uses these to reach you about pickups.'),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('FULL NAME', style: _label),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: field('e.g. Priya Sharma', Icons.person_outline),
          ),
          const SizedBox(height: 14),
          const Text('MOBILE NUMBER', style: _label),
          const SizedBox(height: 6),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: field('10-digit mobile', Icons.phone_outlined, prefix: '+91 '),
            onSubmitted: (_) => _join(),
          ),
          portalError(_error),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _join,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            child: Text(_busy ? 'Joining…' : 'Join and book'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.center, children: [change, signOut]),
    ]);
  }
}
