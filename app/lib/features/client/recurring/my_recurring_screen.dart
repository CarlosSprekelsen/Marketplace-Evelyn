import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/date_formatter.dart';
import '../state/client_requests_providers.dart';

class MyRecurringScreen extends ConsumerStatefulWidget {
  const MyRecurringScreen({super.key});

  @override
  ConsumerState<MyRecurringScreen> createState() => _MyRecurringScreenState();
}

class _MyRecurringScreenState extends ConsumerState<MyRecurringScreen> {
  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(myRecurringRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes Recurrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/client/recurring/new'),
          ),
        ],
      ),
      body: recurringAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No tienes solicitudes recurrentes',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/client/recurring/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear solicitud recurrente'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myRecurringRequestsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final r = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.repeat, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.summary,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${r.districtName ?? 'Distrito'} — ${r.hoursRequested} hora(s)',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.fullAddress,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Próxima: ${formatDateTime(r.nextScheduledAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => _confirmCancel(r.id),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Cancelar serie'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: ${mapDioErrorToMessage(error)}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar recurrencia'),
        content: const Text('Se dejará de generar solicitudes automáticas. Las solicitudes ya creadas no se afectan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(clientRequestsRepositoryProvider);
      await repo.cancelRecurringRequest(id);
      ref.invalidate(myRecurringRequestsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${mapDioErrorToMessage(error)}')),
      );
    }
  }
}
