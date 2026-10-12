import '../../../../core/network/scoped_list_cubit.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/load_appointments.dart';

class AppointmentsCubit extends ScopedListCubit<Appointment> {
  AppointmentsCubit(ClinicScope scope, LoadAppointments load)
    : super(scope, load.call);
}
