import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/state/auth_notifier.dart';
import '../../features/auth/state/auth_state.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/client/my_requests/my_requests_screen.dart';
import '../../features/client/my_requests/request_detail_screen.dart';
import '../../features/client/presentation/client_home_screen.dart';
import '../../features/client/request_form/request_form_screen.dart';
import '../../features/provider/available_jobs/available_jobs_screen.dart';
import '../../features/provider/my_jobs/my_jobs_screen.dart';
import '../../features/provider/presentation/provider_home_screen.dart';
import '../../features/client/recurring/recurring_form_screen.dart';
import '../../features/client/recurring/my_recurring_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          prefillEmail: state.uri.queryParameters['email'],
          prefillToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Términos y Condiciones',
          content:
              'Al crear una cuenta aceptas usar MarketPlace Evelyn de forma responsable. '
              'Debes proveer datos reales, respetar a otros usuarios y cumplir las normas locales. '
              'La plataforma puede suspender cuentas por fraude, abuso o incumplimiento operativo.',
        ),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Política de Privacidad',
          content:
              'Tus datos se usan para operar el servicio de limpieza: autenticación, asignación '
              'de solicitudes, comunicación y soporte. No compartimos información sensible fuera '
              'de los casos necesarios para prestar el servicio o cumplir obligaciones legales.',
        ),
      ),
      GoRoute(
        path: '/client/home',
        builder: (context, state) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/client/request/new',
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return RequestFormScreen(
            prefillDistrictId: qp['district_id'],
            prefillAddressStreet: qp['address_street'],
            prefillAddressNumber: qp['address_number'],
            prefillAddressFloorApt: qp['address_floor_apt'],
            prefillAddressReference: qp['address_reference'],
            prefillHours: int.tryParse(qp['hours'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/client/requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/client/requests/:id',
        builder: (context, state) => RequestDetailScreen(
          requestId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/client/recurring',
        builder: (context, state) => const MyRecurringScreen(),
      ),
      GoRoute(
        path: '/client/recurring/new',
        builder: (context, state) => const RecurringFormScreen(),
      ),
      GoRoute(
        path: '/provider/home',
        builder: (context, state) => const ProviderHomeScreen(),
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/provider/jobs/available',
        builder: (context, state) => const AvailableJobsScreen(),
      ),
      GoRoute(
        path: '/provider/jobs/mine',
        builder: (context, state) => const MyJobsScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password' ||
          location == '/reset-password';
      final isLegalRoute = location.startsWith('/legal/');

      if (authState.status == AuthStatus.loading) {
        return location == '/splash' ? null : '/splash';
      }

      if (authState.status == AuthStatus.unauthenticated || authState.status == AuthStatus.error) {
        return isAuthRoute || isLegalRoute ? null : '/login';
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
        if (user.role == UserRole.client && location.startsWith('/admin')) {
          return '/client/home';
        }
        if (user.role == UserRole.provider && location.startsWith('/client')) {
          return '/provider/home';
        }
        if (user.role == UserRole.provider && location.startsWith('/admin')) {
          return '/provider/home';
        }
        if (user.role == UserRole.admin &&
            (location.startsWith('/client') || location.startsWith('/provider'))) {
          return '/admin/home';
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
  if (role == UserRole.admin) {
    return '/admin/home';
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
