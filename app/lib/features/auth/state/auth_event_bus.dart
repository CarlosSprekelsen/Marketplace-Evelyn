import 'dart:async';

enum AuthEvent {
  sessionExpired,
}

class AuthEventBus {
  AuthEventBus();

  final StreamController<AuthEvent> _controller = StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
