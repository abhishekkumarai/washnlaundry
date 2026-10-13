import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Runs [body] with every `package:http` call answered as "server unreachable",
/// whatever is actually listening on this machine (a local `manage.py
/// runserver` or the Docker backend on :8000 would otherwise answer, and tests
/// that expect a failed load would flake).
Future<T> withOfflineHttp<T>(Future<T> Function() body) => http.runWithClient(
      body,
      () => MockClient((request) async =>
          throw http.ClientException('offline (mocked)', request.url)),
    );

/// Answers the Demo Mode sandbox endpoints; records whether `/demo/end/` was hit.
Future<T> withFakeDemoServer<T>(Future<T> Function() body, {List<String>? calls}) =>
    http.runWithClient(
      body,
      () => MockClient((request) async {
        calls?.add(request.url.path);
        if (request.url.path.endsWith('/demo/start/')) {
          return http.Response(
              jsonEncode({
                'token': 'demo.test',
                'shop': {'id': 1, 'slug': 'demo-abc', 'name': 'Demo Laundry'},
              }),
              201);
        }
        return http.Response('{"ok": true}', 200);
      }),
    );
