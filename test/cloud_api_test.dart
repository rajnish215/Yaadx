import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaadx/backend/cloud_api.dart';

void main() {
  test('API configuration refuses external HTTP and embedded credentials', () {
    for (final url in [
      'http://example.com',
      'https:',
      'https://example.com/hidden-path',
      'https://user:secret@example.com',
      'https://example.com?token=secret',
    ]) {
      expect(
        () => CloudApi(
          baseUrl: url,
          currentUid: () => 'alice',
          token: (_) async => 'token',
        ),
        throwsArgumentError,
      );
    }
  });
  test(
    '401 refreshes token once; authenticated requests never follow redirects',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String?>[];
      final forced = <bool>[];
      final subscription = server.listen((req) async {
        requests.add(req.headers.value(HttpHeaders.authorizationHeader));
        req.response.headers.contentType = ContentType.json;
        if (req.uri.path == '/redirect') {
          req.response.statusCode = 302;
          req.response.headers.set('location', 'http://example.com');
        } else if (requests.length == 1) {
          req.response.statusCode = 401;
          req.response.write('{"error":"unauthenticated"}');
        } else {
          req.response.write(jsonEncode({'ok': true}));
        }
        await req.response.close();
      });
      final api = CloudApi(
        baseUrl: 'http://127.0.0.1:${server.port}',
        currentUid: () => 'alice',
        token: (force) async {
          forced.add(force);
          return force ? 'fresh' : 'old';
        },
      );
      try {
        expect((await api.request('alice', 'GET', '/v1/profile'))['ok'], true);
        expect(forced, [false, true]);
        expect(requests, ['Bearer old', 'Bearer fresh']);
        await expectLater(
          api.request('alice', 'GET', '/redirect'),
          throwsA(isA<CloudFailure>().having((e) => e.status, 'status', 302)),
        );
        expect(requests.length, 3);
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'account change while token is fetched aborts before sending a request',
    () async {
      var uid = 'alice';
      final api = CloudApi(
        baseUrl: 'http://127.0.0.1:1',
        currentUid: () => uid,
        token: (_) async {
          uid = 'bob';
          return 'alice-token';
        },
      );
      await expectLater(
        api.request('alice', 'GET', '/v1/reminders'),
        throwsA(
          isA<CloudFailure>().having((e) => e.code, 'code', 'account_changed'),
        ),
      );
    },
  );
}
