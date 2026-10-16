import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/booking_repository.dart';

class SupabaseAvailabilityUpdates implements AvailabilityUpdates {
  SupabaseAvailabilityUpdates(this.client);
  final SupabaseClient? client;
  @override
  Stream<void> watch(String clinic, String doctor) {
    final db = client;
    if (db == null) return const Stream.empty();
    RealtimeChannel? channel;
    bool connected = false;
    final seen = <String>{};
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = db
            .channel('availability:$clinic:$doctor')
            .onBroadcast(
              event: 'availability_changed',
              callback: (payload) {
                final event = payload['event_id'];
                if (payload['clinic_id'] == clinic &&
                    payload['doctor_id'] == doctor &&
                    event is String &&
                    !seen.contains(event) &&
                    !controller.isClosed) {
                  seen.add(event);
                  if (seen.length > 256) seen.remove(seen.first);
                  controller.add(null);
                }
              },
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed &&
                  !controller.isClosed) {
                if (connected) controller.add(null);
                connected = true;
              }
            });
      },
      onCancel: () async {
        if (channel != null) await db.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}
