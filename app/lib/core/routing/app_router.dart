import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_notifier.dart';
import '../../features/auth/state/auth_state.dart';
import '../../features/client/presentation/client_home_screen.dart';
import '../../features/provider/presentation/provider_home_screen.dart';
import '../../shared/models/user.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(authNotifierProvider.notifier);
  final refresh = _RouterRefreshStream(notifier.stream);

  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/client/home',
        builder: (context, state) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/provider/home',
        builder: (context, state) => const ProviderHomeScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';

      if (authState.status == AuthStatus.loading) {
        return location == '/splash' ? null : '/splash';
      }

      if (authState.status == AuthStatus.unauthenticated || authState.status == AuthStatus.error) {
        return isAuthRoute ? null : '/login';
      }

      if (authState.status == AuthStatus.authenticated) {
        final user = authState.user;
        if (user == null) {
          return '/login';
        }

        final targetHome = _homeByRole(user.role);
        if (location == '/splash' || isAuthRoute) {
          return targetHome;
        }
        if (user.role == UserRole.client && location.startsWith('/provider')) {
          return '/client/home';
        }
        if (user.role == UserRole.provider && location.startsWith('/client')) {
          return '/provider/home';
        }
      }

      return null;
    },
  );
});

String _homeByRole(UserRole role) {
  if (role == UserRole.provider) {
    return '/provider/home';
  }
  return '/client/home';
}

class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
