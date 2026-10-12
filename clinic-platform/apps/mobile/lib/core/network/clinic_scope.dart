import 'package:clinic_mobile/core/cancellation/request_cancellation.dart';

class ClinicScope {
  RequestCancellation token = RequestCancellation();
  int generation = 0;
  final List<void Function()> _reset = [];
  void Function() onReset(void Function() callback) {
    _reset.add(callback);
    return () => _reset.remove(callback);
  }

  void invalidate() {
    token.cancel();
    token = RequestCancellation();
    generation++;
    for (final reset in List.of(_reset)) {
      reset();
    }
  }

  bool current(int version) => version == generation;
}
