import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/clinic_scope.dart';
import '../../domain/entities/auth_identity.dart';
import '../../domain/usecases/auth_actions.dart';

enum AuthStatus {
  initial,
  restoring,
  guest,
  sending,
  codeSent,
  verifying,
  profileRequired,
  authenticated,
  error,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.identity,
    this.profile,
    this.phone = '',
    this.resendAt,
    this.failure,
  });
  final AuthStatus status;
  final AuthIdentity? identity;
  final PatientProfile? profile;
  final String phone;
  final DateTime? resendAt;
  final FailureKind? failure;
  bool get signedIn => identity != null;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.actions, this.scope, {DateTime Function()? now})
    : now = now ?? DateTime.now,
      super(const AuthState()) {
    _subscription = actions.auth.changes.listen(
      (identity) {
        if (identity == null) {
          _version++;
          scope.invalidate();
          emit(const AuthState(status: AuthStatus.guest));
        }
      },
      onError: (Object error) {
        final failure = error is AppException
            ? error.kind
            : FailureKind.unknown;
        _version++;
        if (failure == FailureKind.unauthorized) {
          scope.invalidate();
        }
        emit(
          AuthState(
            status: AuthStatus.error,
            identity: failure == FailureKind.unauthorized
                ? null
                : state.identity,
            profile: failure == FailureKind.unauthorized ? null : state.profile,
            failure: failure,
          ),
        );
      },
    );
  }
  final AuthActions actions;
  final ClinicScope scope;
  final DateTime Function() now;
  StreamSubscription<AuthIdentity?>? _subscription;
  int _version = 0;
  bool get configured => actions.auth.configured;
  bool get ready =>
      state.status != AuthStatus.initial &&
      state.status != AuthStatus.restoring;
  int get resendSeconds => state.resendAt == null
      ? 0
      : ((state.resendAt!.difference(now()).inMilliseconds / 1000).ceil())
            .clamp(0, 60);
  Future<void> restore() async {
    final version = ++_version;
    emit(const AuthState(status: AuthStatus.restoring));
    try {
      final identity = await actions.restore();
      if (version != _version) return;
      if (identity == null) {
        emit(const AuthState(status: AuthStatus.guest));
        return;
      }
      await _loadProfile(identity, version);
    } on AppException catch (e) {
      if (version == _version) {
        emit(AuthState(status: AuthStatus.error, failure: e.kind));
      }
    }
  }

  Future<void> send(String phone) async {
    if (state.status == AuthStatus.sending || resendSeconds > 0) return;
    final version = ++_version;
    emit(AuthState(status: AuthStatus.sending, phone: phone));
    try {
      await actions.send(phone);
      if (version == _version) {
        emit(
          AuthState(
            status: AuthStatus.codeSent,
            phone: phone,
            resendAt: now().add(const Duration(seconds: 60)),
          ),
        );
      }
    } on AppException catch (e) {
      if (version == _version) {
        emit(
          AuthState(status: AuthStatus.error, phone: phone, failure: e.kind),
        );
      }
    }
  }

  Future<void> verify(String code) async {
    if (state.status == AuthStatus.verifying) return;
    final previous = state;
    final version = ++_version;
    emit(
      AuthState(
        status: AuthStatus.verifying,
        phone: previous.phone,
        resendAt: previous.resendAt,
      ),
    );
    try {
      final identity = await actions.verify(previous.phone, code);
      if (version == _version) await _loadProfile(identity, version);
    } on AppException catch (e) {
      if (version == _version) {
        emit(
          AuthState(
            status: AuthStatus.error,
            phone: previous.phone,
            resendAt: previous.resendAt,
            failure: e.kind,
          ),
        );
      }
    }
  }

  Future<void> _loadProfile(AuthIdentity identity, int version) async {
    try {
      final profile = await actions.profile();
      if (version != _version) return;
      scope.invalidate();
      emit(
        AuthState(
          status: profile?.complete == true
              ? AuthStatus.authenticated
              : AuthStatus.profileRequired,
          identity: identity,
          profile: profile,
        ),
      );
    } on AppException catch (e) {
      if (version == _version) {
        emit(
          AuthState(
            status: AuthStatus.error,
            identity: identity,
            failure: e.kind,
          ),
        );
      }
    }
  }

  Future<void> retryProfile() async {
    final identity = state.identity ?? actions.auth.current;
    if (identity != null) {
      await _loadProfile(identity, ++_version);
    } else {
      await restore();
    }
  }

  Future<void> complete(String name, String? email, String language) async {
    final identity = state.identity;
    if (identity == null) return;
    final version = ++_version;
    emit(AuthState(status: AuthStatus.profileRequired, identity: identity));
    try {
      final profile = await actions.complete(name, email, language);
      if (version == _version) {
        emit(
          AuthState(
            status: AuthStatus.authenticated,
            identity: identity,
            profile: profile,
          ),
        );
      }
    } on AppException catch (e) {
      if (version == _version) {
        emit(
          AuthState(
            status: AuthStatus.error,
            identity: identity,
            failure: e.kind,
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    try {
      await actions.logout();
      _version++;
      scope.invalidate();
      emit(const AuthState(status: AuthStatus.guest));
    } on AppException catch (e) {
      emit(
        AuthState(
          status: AuthStatus.error,
          identity: state.identity,
          profile: state.profile,
          failure: e.kind,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
