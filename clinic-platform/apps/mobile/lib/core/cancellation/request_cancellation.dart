/// Framework-independent cancellation shared by domain use cases and adapters.
class RequestCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  final List<void Function()> _listeners = [];
  void Function() listen(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }
}
