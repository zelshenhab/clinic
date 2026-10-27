import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/features/family/data/repositories/api_family_repository.dart';
import 'package:clinic_mobile/features/family/domain/entities/family_member.dart';

const member = '10000000-0000-4000-8000-000000000009';
Dio transport(List<RequestOptions> calls, {int status = 200, Object? error}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, h) {
        calls.add(o);
        if (error != null) {
          h.reject(
            DioException(
              requestOptions: o,
              response: Response(
                requestOptions: o,
                statusCode: status,
                data: error,
              ),
            ),
          );
          return;
        }
        final row = {
          'id': member,
          'full_name': 'Fictional child',
          'relationship': 'child',
          'date_of_birth': '2020-05-01',
        };
        h.resolve(
          Response(
            requestOptions: o,
            statusCode: status,
            data: {
              'success': true,
              'data': o.method == 'GET'
                  ? [row]
                  : o.method == 'DELETE'
                  ? null
                  : row,
            },
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test('family members are private and parsed with relationship', () async {
    final calls = <RequestOptions>[];
    final repo = ApiFamilyRepository(
      ApiClient('', transport: transport(calls)),
    );
    final list = await repo.list(RequestCancellation());
    expect(calls.single.extra['private'], true);
    expect(list.single.relationship, FamilyRelationship.child);
    expect(list.single.dateOfBirth, DateTime(2020, 5, 1));
    await repo.add(' Fictional child ', FamilyRelationship.child, null);
    expect(calls.last.method, 'POST');
    expect(calls.last.extra['private'], true);
    expect(calls.last.data, {
      'full_name': 'Fictional child',
      'relationship': 'child',
      'date_of_birth': null,
    });
    await repo.update(
      member,
      'Fictional parent',
      FamilyRelationship.parent,
      DateTime(1970, 1, 2),
    );
    expect(calls.last.method, 'PATCH');
    expect(calls.last.path, '/me/family-members/$member');
    expect((calls.last.data as Map)['date_of_birth'], '1970-01-02');
    await repo.remove(member);
    expect(calls.last.method, 'DELETE');
  });
  test('reaching the family limit maps to a dedicated failure', () async {
    final repo = ApiFamilyRepository(
      ApiClient(
        '',
        transport: transport(
          [],
          status: 409,
          error: {
            'success': false,
            'error': {'code': 'FAMILY_LIMIT_REACHED'},
          },
        ),
      ),
    );
    await expectLater(
      repo.add('Child', FamilyRelationship.child, null),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          FailureKind.familyLimit,
        ),
      ),
    );
  });
}
