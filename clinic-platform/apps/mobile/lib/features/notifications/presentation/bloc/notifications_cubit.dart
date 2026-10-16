import 'dart:async';
import '../../../../core/network/scoped_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/clinic_notification.dart';
import '../../domain/usecases/load_notifications.dart';

class NotificationsCubit extends ScopedListCubit<ClinicNotification> {
  NotificationsCubit(
    ClinicScope scope,
    LoadNotifications load, {
    Stream<void> Function(String clinic)? updates,
  }) : super(scope, load.call, updates: updates);
}
