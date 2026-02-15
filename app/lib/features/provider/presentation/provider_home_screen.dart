import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_notifier.dart';
import '../state/provider_jobs_providers.dart';

class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  ConsumerState<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends ConsumerState<ProviderHomeScreen> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final notifier = ref.read(authNotifierProvider.notifier);
    final isAvailable = user?.isAvailable ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Proveedor'),
        actions: [
          IconButton(
            onPressed: () => notifier.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido, ${user?.fullName ?? ''}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(isAvailable ? 'Disponible' : 'No disponible'),
              subtitle: Text(
                isAvailable
                    ? 'Recibiras solicitudes de tu zona'
                    : 'No recibiras solicitudes',
              ),
              value: isAvailable,
              onChanged: _toggling ? null : _toggleAvailability,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/provider/jobs/available'),
              child: const Text('Trabajos Disponibles'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.push('/provider/jobs/mine'),
              child: const Text('Mis Trabajos'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _toggling = true);
    try {
      final repo = ref.read(providerJobsRepositoryProvider);
      await repo.setAvailability(value);
      // Refresh user profile to reflect the change
      ref.read(authNotifierProvider.notifier).refreshProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar disponibilidad')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }
}
