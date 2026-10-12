import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/clinic_selection/data/repositories/api_clinic_repository.dart';
import 'package:clinic_mobile/features/clinic_selection/data/datasources/clinic_remote_source.dart';
import 'support/fakes.dart';

class QueueAdapter implements HttpClientAdapter {
  QueueAdapter(this.responses);
  final List<(int, dynamic)> responses;
  int calls = 0;
  final headers = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    headers.add(Map.of(options.headers));
    final (status, data) = responses[calls++];
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ApiClient client(QueueAdapter adapter, {FakeAuth? auth}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = adapter;
    return ApiClient('https://api.example.test', auth: auth, transport: dio);
  }

  test(
    'retries a private request only once and expires repeated unauthorized sessions',
    () async {
      final auth = FakeAuth()..token = 'old';
      final adapter = QueueAdapter([(401, {}), (401, {})]);
      await expectLater(
        client(adapter, auth: auth).get('/me/profile', private: true),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.unauthorized,
          ),
        ),
      );
      expect(adapter.calls, 2);
      expect(auth.refreshCalls, 1);
      expect(auth.expires, 1);
      expect(adapter.headers.last['Authorization'], 'Bearer new-token');
      await auth.events.close();
    },
  );
  test(
    'refresh retry returns real response and public reads send no bearer token',
    () async {
      final auth = FakeAuth()..token = 'old';
      final adapter = QueueAdapter([
        (401, {}),
        (
          200,
          {
            'success': true,
            'data': {'id': 'user'},
          },
        ),
        (200, {'success': true, 'data': []}),
      ]);
      final api = client(adapter, auth: auth);
      expect(await api.get('/me/profile', private: true), {'id': 'user'});
      await api.get('/clinics');
      expect(adapter.headers.last.containsKey('Authorization'), false);
      await auth.events.close();
    },
  );
  test(
    'repository rejects malformed records rather than inventing clinic data',
    () async {
      final adapter = QueueAdapter([
        (
          200,
          {
            'success': true,
            'data': [
              {'id': 'clinic_001'},
            ],
          },
        ),
      ]);
      await expectLater(
        ApiClinicRepository(ClinicRemoteSource(client(adapter))).list(),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            FailureKind.invalidResponse,
          ),
        ),
      );
    },
  );
  test('maps rate limiting and unavailable server to typed failures', () async {
    for (final pair in [
      (429, FailureKind.rateLimited),
      (503, FailureKind.server),
    ]) {
      await expectLater(
        client(QueueAdapter([(pair.$1, {})])).get('/clinics'),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', pair.$2)),
      );
    }
  });
}
