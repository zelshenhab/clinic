import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_mobile/core/network/clinic_scope.dart';
import 'package:clinic_mobile/core/network/scoped_list_cubit.dart';

void main() {
  test(
    'switch clears data immediately and ignores late old-clinic responses',
    () async {
      final scope = ClinicScope();
      final old = Completer<List<String>>();
      final cubit = ScopedListCubit<String>(
        scope,
        (id, token) => id == 'A' ? old.future : Future.value(['B item']),
      );
      final request = cubit.load('A');
      scope.invalidate();
      expect(cubit.state.items, isEmpty);
      await cubit.load('B');
      old.complete(['A private item']);
      await request;
      expect(cubit.state.clinicId, 'B');
      expect(cubit.state.items, ['B item']);
      await cubit.close();
    },
  );
  test('logout/reset erases successful scoped data', () async {
    final scope = ClinicScope();
    final cubit = ScopedListCubit<String>(scope, (_, _) async => ['private']);
    await cubit.load('A');
    scope.invalidate();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.status, ListStatus.initial);
    await cubit.close();
  });
}
