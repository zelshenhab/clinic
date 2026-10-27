import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/core/localization/app_localizations.dart';
import 'package:clinic_mobile/core/network/api_client.dart';
import 'package:clinic_mobile/core/utils/document_opener.dart';
import 'package:clinic_mobile/features/documents/data/repositories/api_documents_repository.dart';
import 'package:clinic_mobile/features/documents/domain/entities/medical_document.dart';
import 'package:clinic_mobile/features/documents/domain/repositories/documents_repository.dart';
import 'package:clinic_mobile/features/documents/presentation/pages/documents_page.dart';

const clinic = '10000000-0000-4000-8000-000000000001',
    record = '10000000-0000-4000-8000-000000000002',
    member = '10000000-0000-4000-8000-000000000003';

class DocumentsFake implements DocumentsRepository {
  int links = 0;
  @override
  Future<List<MedicalDocument>> list(String c, RequestCancellation t) async => [
    MedicalDocument(
      id: 'own',
      kind: DocumentKind.labResult,
      title: 'Fictional blood test',
      fileName: 'blood.pdf',
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 10, 20, 6),
    ),
    MedicalDocument(
      id: 'child',
      kind: DocumentKind.report,
      title: 'Fictional child report',
      fileName: 'report.pdf',
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 10, 21, 6),
      familyMemberId: member,
      familyMemberName: 'Fictional child',
    ),
  ];
  @override
  Future<Uri> link(String c, String id) async {
    links++;
    return Uri.parse('https://example.invalid/$id');
  }
}

class OpenerFake extends DocumentOpener {
  final opened = <Uri>[];
  bool fail = false;
  @override
  Future<void> open(Uri url) async {
    if (fail) throw const AppException(FailureKind.unknown);
    opened.add(url);
  }
}

void main() {
  test(
    'documents are private, clinic scoped and links must be web URLs',
    () async {
      final calls = <RequestOptions>[];
      var url = 'https://example.invalid/signed';
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': o.path.endsWith('/download')
                      ? {'url': url}
                      : [
                          {
                            'id': record,
                            'clinic_id': clinic,
                            'kind': 'lab_result',
                            'title': 'Fictional blood test',
                            'file_name': 'blood.pdf',
                            'mime_type': 'application/pdf',
                            'created_at': '2026-10-20T06:00:00+00:00',
                            'doctor_name': {'ru': 'Врач', 'en': 'Doctor'},
                            'family_member_id': member,
                            'family_member_name': 'Fictional child',
                          },
                        ],
                },
              ),
            );
          },
        ),
      );
      final repo = ApiDocumentsRepository(ApiClient('', transport: dio));
      final list = await repo.list(clinic, RequestCancellation());
      expect(calls.single.path, '/clinics/$clinic/medical-records');
      expect(calls.single.extra['private'], true);
      expect(list.single.kind, DocumentKind.labResult);
      expect(list.single.familyMemberName, 'Fictional child');
      expect((await repo.link(clinic, record)).toString(), url);
      expect(calls.last.extra['private'], true);
      url = 'javascript:alert(1)';
      await expectLater(
        repo.link(clinic, record),
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

  for (final language in ['ru', 'en']) {
    testWidgets(
      'documents filter by person and open a fresh link at 320px in $language',
      (tester) async {
        tz.initializeTimeZones();
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = DocumentsFake(), opener = OpenerFake();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DocumentsPage(
              clinicId: clinic,
              timezone: 'Europe/Moscow',
              documents: repo,
              opener: opener,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fictional blood test'), findsOneWidget);
        expect(find.text('Fictional child report'), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Fictional child'));
        await tester.pumpAndSettle();
        expect(find.text('Fictional blood test'), findsNothing);
        await tester.tap(find.text('Fictional child report'));
        await tester.pumpAndSettle();
        expect(
          opener.opened.single.toString(),
          'https://example.invalid/child',
        );
        await tester.tap(
          find.widgetWithText(
            ChoiceChip,
            language == 'ru' ? 'Для меня' : 'Myself',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fictional child report'), findsNothing);
        opener.fail = true;
        await tester.tap(find.text('Fictional blood test'));
        await tester.pumpAndSettle();
        expect(repo.links, 2);
        expect(
          find.text(
            language == 'ru'
                ? 'Не удалось открыть документ. Попробуйте снова.'
                : 'Could not open the document. Try again.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
