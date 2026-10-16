import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/patient_tools_repository.dart';

class SupabasePatientUpdates implements PatientUpdates {
  SupabasePatientUpdates(this.client);
  final SupabaseClient? client;
  @override
  Stream<void> watch(String clinic) {
    final db = client, user = client?.auth.currentUser?.id;
    if (db == null || user == null) return const Stream.empty();
    RealtimeChannel? channel;
    final seen = <String>{};
    late final StreamController<void> controller;
    void receive(Map<String, dynamic> payload) {
      final event = payload['event_id'];
      if (payload['clinic_id'] == clinic &&
          event is String &&
          seen.add(event) &&
          !controller.isClosed) {
        if (seen.length > 256) seen.remove(seen.first);
        controller.add(null);
      }
    }

    controller = StreamController<void>(
      onListen: () {
        channel = db
            .channel(
              'patient:$clinic:$user',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(event: 'appointment_changed', callback: receive)
            .onBroadcast(event: 'notification_changed', callback: receive)
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed &&
                  !controller.isClosed) {
                controller.add(null);
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
