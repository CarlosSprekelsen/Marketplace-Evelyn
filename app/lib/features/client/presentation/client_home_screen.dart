import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_notifier.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final notifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Cliente'),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/client/request/new'),
              child: const Text('Solicitar Limpieza'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.push('/client/requests'),
              child: const Text('Mis Solicitudes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/client/recurring'),
              icon: const Icon(Icons.repeat),
              label: const Text('Solicitudes Recurrentes'),
            ),
          ],
        ),
      ),
    );
  }
}
