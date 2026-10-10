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
