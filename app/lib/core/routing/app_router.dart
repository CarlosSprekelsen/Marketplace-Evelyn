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
import '../../features/client/addresses/addresses_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../shared/models/user.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen<AuthState>(authNotifierProvider, (previous, next) {
    refresh.trigger();
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ClientShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/home',
                builder: (context, state) => const ClientHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/requests',
                builder: (context, state) => const MyRequestsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RequestDetailScreen(
                      requestId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/client/addresses',
                builder: (context, state) => const AddressesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/client/request/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final qp = state.uri.queryParameters;
          return RequestFormScreen(
            prefillDistrictId: qp['district_id'],
            prefillHours: int.tryParse(qp['hours'] ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/client/recurring',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyRecurringScreen(),
      ),
      GoRoute(
        path: '/client/recurring/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecurringFormScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ProviderShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/home',
                builder: (context, state) => const ProviderHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/jobs/available',
                builder: (context, state) => const AvailableJobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/jobs/mine',
                builder: (context, state) => const MyJobsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminHomeScreen(),
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier();

  void trigger() {
    notifyListeners();
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
