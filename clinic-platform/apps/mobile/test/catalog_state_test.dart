import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clinic_mobile/core/catalog/catalog_list_cubit.dart';
import 'package:clinic_mobile/core/catalog/scoped_resource_cubit.dart';
import 'package:clinic_mobile/core/catalog/catalog_query.dart';
import 'package:clinic_mobile/core/catalog/catalog_page.dart';
import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';
import 'package:clinic_mobile/core/errors/app_exception.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';

void main() {
  test(
    'cancels stale search responses, debounces input and retains filter query',
    () {
      fakeAsync((clock) {
        final calls = <CatalogQuery>[],
            pending = <Completer<CatalogPage<String>>>[],
            tokens = <RequestCancellation>[];
        final scope = ClinicScope();
        final c = CatalogListCubit<String>(scope, (
          clinic,
          token, {
          query = const CatalogQuery(),
        }) {
          calls.add(query);
          tokens.add(token);
          final p = Completer<CatalogPage<String>>();
          pending.add(p);
          return p.future;
        });
        c.load('A', query: const CatalogQuery(specialtyId: 'specialty'));
        c.search('A');
        c.search('Anna');
        clock.elapse(const Duration(milliseconds: 349));
        expect(calls.length, 1);
        clock.elapse(const Duration(milliseconds: 1));
        expect(calls.length, 2);
        expect(calls.last.search, 'Anna');
        expect(calls.last.specialtyId, 'specialty');
        pending[1].complete(
          const CatalogPage(items: ['Anna'], page: 1, total: 1, hasMore: false),
        );
        clock.flushMicrotasks();
        pending[0].complete(
          const CatalogPage(items: ['old'], page: 1, total: 1, hasMore: false),
        );
        clock.flushMicrotasks();
        expect(c.state.items, ['Anna']);
        expect(tokens.first.isCancelled, true);
        c.close();
      });
    },
  );
  test('deduplicates concurrent identical page loads', () async {
    final pending = Completer<CatalogPage<String>>();
    var calls = 0;
    final c = CatalogListCubit<String>(ClinicScope(), (
      clinic,
      token, {
      query = const CatalogQuery(),
    }) {
      calls++;
      return pending.future;
    });
    final a = c.load('A'), b = c.load('A');
    expect(identical(a, b), true);
    expect(calls, 1);
    pending.complete(
      const CatalogPage(items: [], page: 1, total: 0, hasMore: false),
    );
    await a;
    expect(c.state.status, CatalogStatus.empty);
    await c.close();
  });
  test(
    'clinic reset clears lists and rejects a late paginated response',
    () async {
      final pending = Completer<CatalogPage<String>>();
      final scope = ClinicScope();
      final c = CatalogListCubit<String>(
        scope,
        (clinic, token, {query = const CatalogQuery()}) async => query.page == 1
            ? CatalogPage(items: [clinic], page: 1, total: 2, hasMore: true)
            : pending.future,
      );
      await c.load('A');
      final next = c.next();
      scope.invalidate();
      expect(c.state.items, isEmpty);
      await c.load('B');
      pending.complete(
        const CatalogPage(
          items: ['A stale'],
          page: 2,
          total: 2,
          hasMore: false,
        ),
      );
      await next;
      expect(c.state.items, ['B']);
      expect(c.state.clinicId, 'B');
      await c.close();
    },
  );
  test(
    'pagination failure preserves page and items; retry appends without skipping',
    () async {
      var fail = true;
      final pages = <int>[];
      final c = CatalogListCubit<String>(ClinicScope(), (
        clinic,
        token, {
        query = const CatalogQuery(),
      }) async {
        pages.add(query.page);
        if (query.page == 2 && fail) {
          throw const AppException(FailureKind.network);
        }
        return CatalogPage(
          items: ['page${query.page}'],
          page: query.page,
          total: 2,
          hasMore: query.page == 1,
        );
      });
      await c.load('A');
      await c.next();
      expect(c.state.items, ['page1']);
      expect(c.state.query.page, 1);
      expect(c.state.failure, FailureKind.network);
      fail = false;
      await c.next();
      expect(pages, [1, 2, 2]);
      expect(c.state.items, ['page1', 'page2']);
      expect(c.state.hasMore, false);
      await c.close();
    },
  );
  test(
    'refresh and changed filter restart page one; empty differs from error',
    () async {
      var fail = true;
      final c = CatalogListCubit<String>(ClinicScope(), (
        clinic,
        token, {
        query = const CatalogQuery(),
      }) async {
        if (fail) throw const AppException(FailureKind.server);
        return const CatalogPage(items: [], page: 1, total: 0, hasMore: false);
      });
      await c.load('A');
      expect(c.state.status, CatalogStatus.error);
      fail = false;
      await c.refresh();
      expect(c.state.status, CatalogStatus.empty);
      await c.filter(const CatalogQuery(page: 4, category: 'diagnostics'));
      expect(c.state.query.page, 1);
      expect(c.state.query.category, 'diagnostics');
      await c.close();
    },
  );
  test(
    'detail resource reset rejects old clinic data and retries failed loading',
    () async {
      final scope = ClinicScope(), pending = Completer<String>();
      final c = ScopedResourceCubit<String>(scope);
      final old = c.fetch('A', (_) => pending.future);
      scope.invalidate();
      await c.fetch(
        'B',
        (_) async => throw const AppException(FailureKind.timeout),
      );
      expect(c.state.failure, FailureKind.timeout);
      await c.fetch('B', (_) async => 'new detail');
      pending.complete('old detail');
      await old;
      expect(c.state.data, 'new detail');
      expect(c.state.clinicId, 'B');
      await c.close();
    },
  );
}
