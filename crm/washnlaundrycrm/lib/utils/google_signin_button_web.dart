import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google's own rendered sign-in button — the GIS SDK requires this on web,
/// it does not allow custom UI that calls `authenticate()`. [onPressed] is
/// accepted only to keep this interchangeable with the non-web stub; GIS
/// reports the result through `GoogleSignIn.authenticationEvents`
/// (`AuthProvider` already listens), not a callback, so it's unused here.
///
/// Selected by `google_signin_button.dart`'s conditional export only when
/// `dart:js_interop` is the compilation target — i.e. only on web, which is
/// the only place this file, or the `dart:js_interop` types it depends on,
/// will actually compile.
Widget googleSignInButton({required VoidCallback onPressed}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      theme: web.GSIButtonTheme.filledBlue,
      size: web.GSIButtonSize.large,
      shape: web.GSIButtonShape.pill,
      text: web.GSIButtonText.signinWith,
    ),
  );
}
