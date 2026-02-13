import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            const SizedBox(height: 8),
            const Text('Panel cliente listo para Sprint 2.'),
          ],
        ),
      ),
    );
  }
}
