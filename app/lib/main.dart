import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'core/routing/app_router.dart';
import 'features/auth/state/auth_notifier.dart';
import 'features/auth/state/auth_state.dart';

/// Set to true if the Google Maps renderer fails to initialize.
/// Checked by screens that embed interactive GoogleMap widgets.
bool googleMapsRendererFailed = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAndroidGoogleMapsRenderer();

  runApp(
    const ProviderScope(
      child: MarketplaceApp(),
    ),
  );
}

Future<void> _configureAndroidGoogleMapsRenderer() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is! GoogleMapsFlutterAndroid) {
    return;
  }

  try {
    // ignore: deprecated_member_use
    await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
  } catch (error) {
    googleMapsRendererFailed = true;
    debugPrint('Google Maps renderer initialization failed: $error');
  }
}

class MarketplaceApp extends ConsumerStatefulWidget {
  const MarketplaceApp({super.key});

  @override
  ConsumerState<MarketplaceApp> createState() => _MarketplaceAppState();
}

class _MarketplaceAppState extends ConsumerState<MarketplaceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.authenticated) {
      unawaited(ref.read(authNotifierProvider.notifier).refreshProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'MarketPlace Evelyn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
