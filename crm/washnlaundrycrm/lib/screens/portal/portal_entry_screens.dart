import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/portal_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/google_signin_button.dart';
import 'portal_shell.dart';

const _heading = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.ink);
const _lede = TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.muted);

/// Customer sign-in: Google, or a one-time code emailed to them (no password).
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() call, {VoidCallback? onOk}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) onOk?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final portal = context.watch<PortalProvider>();
    return PortalPage(children: [
      Text(portal.shop == null ? 'Sign in' : 'Sign in to book with ${portal.shopName}',
          style: _heading),
      const SizedBox(height: 8),
      const Text('Book pickups and follow your orders. No password needed.', style: _lede),
      const SizedBox(height: 24),
      if (AuthProvider.isConfigured) ...[
        Center(child: googleSignInButton(onPressed: auth.authenticate)),
        const SizedBox(height: 20),
        const Row(children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or with email', style: TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ]),
        const SizedBox(height: 20),
      ],
      TextField(
        controller: _email,
        enabled: !_codeSent,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        onSubmitted: (_) => _codeSent ? null : _send(auth),
      ),
      if (_codeSent) ...[
        const SizedBox(height: 12),
        Text('We sent a 6-digit code to ${_email.text.trim()}.',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: const InputDecoration(
              labelText: 'Code', border: OutlineInputBorder(), counterText: ''),
          onSubmitted: (_) => _verify(auth),
        ),
      ],
      portalError(_error ?? auth.error),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : () => _codeSent ? _verify(auth) : _send(auth),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Text(_busy
            ? 'Please wait…'
            : _codeSent
                ? 'Sign in'
                : 'Email me a code'),
      ),
      if (_codeSent)
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _codeSent = false;
                    _code.clear();
                    _error = null;
                  }),
          child: const Text('Use a different email'),
        ),
      const SizedBox(height: 24),
      TextButton(
          onPressed: () => context.go('/find'), child: const Text('Find a laundry near you')),
    ]);
  }

  void _send(AuthProvider auth) =>
      _run(() => auth.requestEmailCode(_email.text), onOk: () => _codeSent = true);

  void _verify(AuthProvider auth) =>
      _run(() => auth.signInWithEmailCode(_email.text, _code.text));
}

/// "Find your laundry": search the shops that take online bookings.
class FindShopScreen extends StatefulWidget {
  const FindShopScreen({super.key});

  @override
  State<FindShopScreen> createState() => _FindShopScreenState();
}

class _FindShopScreenState extends State<FindShopScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _shops;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shops = await ApiService.searchShops(_q.text.trim());
      if (mounted) setState(() => _shops = shops);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pick(Map<String, dynamic> shop) async {
    final err = await context.read<PortalProvider>().selectShop(shop['slug'] as String);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      context.go('/book');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = _shops;
    return PortalPage(children: [
      const Text('Find your laundry', style: _heading),
      const SizedBox(height: 8),
      const Text('Search by shop name, city or your 6-digit pincode.', style: _lede),
      const SizedBox(height: 20),
      TextField(
        controller: _q,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'e.g. 560038 or Indiranagar',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ),
        onSubmitted: (_) => _search(),
      ),
      portalError(_error),
      const SizedBox(height: 16),
      if (_busy && shops == null) const Center(child: CircularProgressIndicator()),
      if (shops != null && shops.isEmpty)
        const Text('No laundry takes online bookings there yet. Try a nearby pincode, '
            'or ask your laundry for its booking link.',
            style: TextStyle(color: AppColors.muted)),
      for (final s in shops ?? const <Map<String, dynamic>>[]) ...[
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pick(s),
          child: PortalPanel(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}', style: AppTypography.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                      [s['address'], s['city'], s['pin_code']]
                          .where((v) => v != null && '$v'.isNotEmpty)
                          .join(', '),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

/// `/s/<slug>`: a shop's own booking link (shared on WhatsApp, the QR on receipts).
class ShopLinkScreen extends StatefulWidget {
  const ShopLinkScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ShopLinkScreen> createState() => _ShopLinkScreenState();
}

class _ShopLinkScreenState extends State<ShopLinkScreen> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<PortalProvider>().selectShop(widget.slug).then((err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PortalProvider>();
    final shop = portal.shop;
    if (_loading) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || shop == null) {
      return PortalPage(children: [
        const Text('This link is not taking bookings', style: _heading),
        const SizedBox(height: 8),
        Text(_error ?? 'The laundry may have switched online booking off.', style: _lede),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: () => context.go('/find'), child: const Text('Find another laundry')),
      ]);
    }
    return PortalPage(children: [
      Text('${shop['name']}', style: _heading),
      const SizedBox(height: 8),
      Text(
          [shop['address'], shop['city'], shop['pin_code']]
              .where((v) => v != null && '$v'.isNotEmpty)
              .join(', '),
          style: _lede),
      if ('${shop['phone'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('${shop['phone']}', style: _lede),
      ],
      const SizedBox(height: 24),
      const Text('Home pickup and delivery. Prices are set by the shop and shown before '
          'you book. Pay when your clothes come back.',
          style: TextStyle(color: AppColors.ink, height: 1.45)),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => context.go('/book'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('Book a pickup'),
      ),
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
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _pending = auth.me?['pending_link'] == true;
    _name.text = auth.userName ?? '';
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
    return PortalPage(children: [
      Text('Join ${portal.shopName}', style: _heading),
      const SizedBox(height: 8),
      Text('Signed in as ${auth.userEmail ?? ''}. Tell the shop who you are.', style: _lede),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Mobile number', prefixText: '+91 ', border: OutlineInputBorder()),
        onSubmitted: (_) => _join(),
      ),
      portalError(_error),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _join,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Text(_busy ? 'Joining…' : 'Continue'),
      ),
      change,
      signOut,
    ]);
  }
}
