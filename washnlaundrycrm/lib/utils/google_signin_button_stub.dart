import 'package:flutter/material.dart';

/// Non-web fallback — [supportsAuthenticate] on `GoogleSignIn` is true off
/// web, so this is a real button wired to `authenticate()`, not a placeholder.
/// Selected by `google_signin_button.dart`'s conditional export whenever
/// `dart:js_interop` isn't the compilation target, which is every platform
/// but web — including the plain-VM target `flutter test` runs on.
Widget googleSignInButton({required VoidCallback onPressed}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Google'),
    ),
  );
}
