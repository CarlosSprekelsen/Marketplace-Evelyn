import '../../../shared/models/user.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.message,
  });

  final AuthStatus status;
  final User? user;
  final String? message;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isError => status == AuthStatus.error;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? message,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      message: message,
    );
  }

  static const loading = AuthState(status: AuthStatus.loading);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}
