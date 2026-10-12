import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/preferences.dart';

class LocaleCubit extends Cubit<String> {
  LocaleCubit(this.preferences)
    : super(preferences.read('language') == 'en' ? 'en' : 'ru');
  final Preferences preferences;
  Future<void> select(String value) async {
    if (value != 'ru' && value != 'en') return;
    await preferences.write('language', value);
    emit(value);
  }
}
