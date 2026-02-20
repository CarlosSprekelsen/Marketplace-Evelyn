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

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> with WidgetsBindingObserver {
  Timer? _pollTimer;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling(forceRefresh: true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('Todos', null),
                const SizedBox(width: 6),
                _filterChip('Pendientes', 'PENDING'),
                const SizedBox(width: 6),
                _filterChip('Aceptadas', 'ACCEPTED'),
                const SizedBox(width: 6),
                _filterChip('En curso', 'IN_PROGRESS'),
                const SizedBox(width: 6),
                _filterChip('Completadas', 'COMPLETED'),
                const SizedBox(width: 6),
                _filterChip('Canceladas', 'CANCELLED'),
                const SizedBox(width: 6),
                _filterChip('Expiradas', 'EXPIRED'),
              ],
            ),
          ),
          Expanded(
            child: requestsAsync.when(
              data: (requests) {
                final filtered = _statusFilter == null
                    ? requests
                    : requests
                        .where((r) => r.status.value == _statusFilter)
                        .toList(growable: false);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No hay solicitudes con este filtro.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(myRequestsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final request = filtered[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        title: Text(request.district?.name ?? 'Distrito ${request.districtId}'),
                        subtitle: Text(
                          '${formatDateTime(request.scheduledAt)} · ${formatPrice(request.priceTotal, request.currency)}',
                        ),
                        trailing: _StatusChip(status: request.status),
                        onTap: () => context.push('/client/requests/${request.id}'),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemCount: filtered.length,
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
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? statusValue) {
    final selected = _statusFilter == statusValue;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = statusValue;
        });
      },
    );
  }

  void _startPolling({bool forceRefresh = false}) {
    if (forceRefresh) {
      // ignore: unused_result
      ref.refresh(myRequestsProvider);
    }
    if (_pollTimer?.isActive ?? false) {
      return;
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        // ignore: unused_result
        ref.refresh(myRequestsProvider);
      },
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
