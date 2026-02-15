import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/service_request_model.dart';
import '../../../shared/utils/date_formatter.dart';
import '../state/client_requests_providers.dart';

class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  late Timer _pollTimer;

  @override
  void initState() {
    super.initState();
    // Auto-poll every 10 seconds to check for status updates
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        // ignore: unused_result
        ref.refresh(myRequestsProvider);
      },
    );
  }

  @override
  void dispose() {
    _pollTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('No tienes solicitudes aún.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myRequestsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  title: Text(request.district?.name ?? 'Distrito ${request.districtId}'),
                  subtitle: Text(
                    '${formatDateTime(request.scheduledAt)} · \$${request.priceTotal.toStringAsFixed(2)}',
                  ),
                  trailing: _StatusChip(status: request.status),
                  onTap: () => context.push('/client/requests/${request.id}'),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: requests.length,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              mapDioErrorToMessage(error),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusMeta(status);
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

(String, Color) _statusMeta(ServiceRequestStatus status) {
  switch (status) {
    case ServiceRequestStatus.pending:
      return ('PENDING', Colors.orange);
    case ServiceRequestStatus.accepted:
      return ('ACCEPTED', Colors.blue);
    case ServiceRequestStatus.inProgress:
      return ('IN_PROGRESS', Colors.indigo);
    case ServiceRequestStatus.completed:
      return ('COMPLETED', Colors.green);
    case ServiceRequestStatus.cancelled:
      return ('CANCELLED', Colors.red);
    case ServiceRequestStatus.expired:
      return ('EXPIRED', Colors.grey);
  }
}
